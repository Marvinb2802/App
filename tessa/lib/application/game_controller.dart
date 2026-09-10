import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/model/game_state.dart';
import '../domain/model/level.dart';
import '../domain/rules/hint.dart';
import '../domain/rules/move.dart';
import '../domain/rules/zen.dart';
import 'daily.dart';
import 'daily_goal.dart';
import 'game_mode.dart';
import 'level_controller.dart';
import 'sound.dart';
import 'providers.dart';
import 'round_log.dart';
import 'shop.dart';

/// Fuehrt die Runde: Zuege, Undo, Neustart.
///
/// Die Regeln selbst stehen in domain/; hier kommt nur die Verwaltung des
/// Verlaufs dazu, den ein Undo braucht, und das Sichern.
class GameController extends Notifier<GameState> {
  /// Die letzten Spielstaende, juengster zuletzt.
  final List<GameState> _history = [];

  @override
  GameState build() =>
      ref.read(restoredGameProvider) ??
      startGame(ref.read(seedSourceProvider)());

  /// Im Tueftel-Modus reicht der Verlauf bis zum Anfang zurueck.
  bool get _unlimitedUndo => ref.read(gameModeProvider) == GameMode.practice;

  /// Nur zum Pruefen in der Oberflaeche (Vorschau, Abwurfziel).
  bool canPlace(int slot, int x, int y) => canPlaceFromHand(state, slot, x, y);

  /// Legt das Teil aus [slot] auf ([x], [y]).
  ///
  /// Gibt false zurueck, wenn der Zug nicht erlaubt ist — dann bleibt der
  /// Spielstand unveraendert.
  bool place({required int slot, required int x, required int y}) {
    if (!canPlaceFromHand(state, slot, x, y)) return false;

    // Was der beste verfuegbare Zug gebracht haette — Grundlage der Analyse
    // am Rundenende. Muss vor dem Zug ermittelt werden.
    final bestMoeglich = findHint(state.board, state.hand)?.clearedLines ?? 0;
    final zugnummer = ref.read(roundLogProvider).moveCount + 1;

    _remember(state);
    var next = applyMove(state, slot: slot, x: x, y: y);
    if (next.isOver && ref.read(gameModeProvider) == GameMode.zen) {
      next = rescue(next);
    }
    state = next;

    ref.read(roundLogProvider.notifier).record(MoveRecord(
          index: zugnummer,
          clearedLines: next.lastMove!.clearedLines,
          bestLines: bestMoeglich,
          points: next.lastMove!.points,
          combo: next.lastMove!.appliedCombo,
        ));

    ref.read(hintProvider.notifier).hide();
    _feedback(next);
    _checkLevel(next);
    unawaited(_checkDailyGoal(next));
    unawaited(_persist(next));
    return true;
  }

  /// Startet ein Level: eigener Spielcode, vorbelegtes Brett, Zugbegrenzung.
  void startLevel(Level level) {
    _history.clear();
    state = startGame(level.seed).copyWith(board: level.start);
    ref.read(hintProvider.notifier).reset();
    ref.read(roundLogProvider.notifier).reset();
    ref.read(levelProvider.notifier).start(level);
  }

  /// Prueft nach jedem Zug, ob das Level geschafft oder verloren ist.
  void _checkLevel(GameState snapshot) {
    if (ref.read(gameModeProvider) != GameMode.level) return;
    final session = ref.read(levelProvider);
    final level = session.level;
    if (level == null || session.outcome != LevelOutcome.playing) return;

    final log = ref.read(roundLogProvider);
    final geschafft = level.goal.reached(
      score: snapshot.score,
      totalLines: log.totalLines,
      bestClear: log.bestClear,
      bestCombo: log.bestCombo,
    );

    if (geschafft) {
      ref.read(levelProvider.notifier).settle(LevelOutcome.won);
      unawaited(_recordLevel(level));
    } else if (snapshot.isOver || log.moveCount >= level.moveLimit) {
      ref.read(levelProvider.notifier).settle(LevelOutcome.lost);
    }
  }

  /// Haelt den Fortschritt fest und schreibt Sterne gut.
  Future<void> _recordLevel(Level level) async {
    ref.read(shopProvider.notifier).earn(3 + level.number ~/ 10);
    final store = ref.read(storeProvider);
    if (store == null) return;
    try {
      final bisher =
          int.tryParse(await store.readSetting('levels.done') ?? '') ?? 0;
      if (level.number > bisher) {
        await store.writeSetting('levels.done', '${level.number}');
        ref.invalidate(levelProgressProvider);
      }
    } catch (_) {
      // Ein misslungenes Speichern darf das Spiel nicht stoppen.
    }
  }

  /// Prueft das Ziel des Tages und haelt es fest, sobald es geschafft ist.
  Future<void> _checkDailyGoal(GameState snapshot) async {
    if (ref.read(gameModeProvider) != GameMode.daily) return;
    final store = ref.read(storeProvider);
    if (store == null) return;

    final today = ref.read(todayProvider);
    final goal = goalForDate(today);
    if (!goal.reachedBy(ref.read(roundLogProvider), snapshot)) return;

    try {
      await recordDailyGoal(store, today);
      ref.read(shopProvider.notifier).earn(starsForDailyGoal);
      ref.invalidate(dailyStatusProvider);
    } catch (_) {
      // Ein misslungenes Speichern darf die Runde nicht stoppen.
    }
  }

  /// Nimmt den letzten Zug zurueck.
  bool undo() {
    if (_history.isEmpty) return false;
    if (!_unlimitedUndo && !state.canUndo) return false;
    final previous = _history.removeLast();
    state = _unlimitedUndo
        ? previous
        : applyUndo(state, previous);
    ref.read(hintProvider.notifier).hide();
    ref.read(roundLogProvider.notifier).undoLast();
    unawaited(_persist(state));
    return true;
  }

  /// Startet eine neue Runde. Ohne [seed] kommt ein frischer Spielcode.
  void restart({int? seed}) {
    _history.clear();
    state = startGame(seed ?? ref.read(seedSourceProvider)());
    ref.read(hintProvider.notifier).reset();
    ref.read(roundLogProvider.notifier).reset();
    unawaited(_persist(state));
  }

  /// Legt zusaetzliche Zurueck-Zuege nach — aus dem Shop.
  void addUndos(int count) {
    if (count <= 0) return;
    state = state.copyWith(undosLeft: state.undosLeft + count);
  }

  /// Spielt nach dem Ende weiter, wenn ein Weiterspielen im Vorrat ist.
  ///
  /// Es wird Platz geschaffen (naechste Hand aus der Steinfolge, notfalls die
  /// vollste Reihe geraeumt) — die Steinfolge selbst bleibt die des
  /// Spielcodes. Punkte und Verlauf bleiben erhalten.
  bool revive() {
    if (!state.isOver) return false;
    if (!ref.read(shopProvider.notifier).consumeRevive()) return false;
    state = rescueUntilPlayable(state);
    unawaited(_persist(state));
    return true;
  }

  /// Spielt dieselbe Runde noch einmal: gleicher Code, gleiche Steinfolge.
  void replay() => restart(seed: state.seed);

  /// Ton und Vibration zum Zug.
  void _feedback(GameState after) {
    final cleared = after.lastMove?.didClear ?? false;
    final sound = ref.read(soundProvider.notifier);

    if (after.isOver) {
      sound.play(Sounds.gameOver);
    } else if (cleared) {
      sound.play(Sounds.clear(after.lastMove!.appliedCombo));
    } else {
      sound.play(Sounds.place);
    }

    if (!ref.read(hapticsProvider)) return;
    if (cleared) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _remember(GameState snapshot) {
    _history.add(snapshot);
    // Ohne Tueftel-Modus wird nie weiter zurueckgegangen als drei Zuege.
    if (!_unlimitedUndo && _history.length > GameState.undosPerRound) {
      _history.removeAt(0);
    }
  }

  /// Sichert den Stand, sofern ein Speicher da ist.
  ///
  /// Eine beendete Runde wandert in die Bestenliste und raeumt die laufende
  /// Partie weg — sie laesst sich nicht fortsetzen.
  Future<void> _persist(GameState snapshot) async {
    // Level-Runden gehoeren nicht in die Bestenliste und lassen sich nicht
    // als offene Partie fortsetzen — ihr Fortschritt steht woanders.
    if (ref.read(gameModeProvider) == GameMode.level) return;
    final store = ref.read(storeProvider);
    if (store == null) return;
    try {
      if (!snapshot.isOver) {
        await store.saveGame(snapshot);
        return;
      }
      await store.addScore(score: snapshot.score, seed: snapshot.seed);
      ref.read(shopProvider.notifier).earn(starsForScore(snapshot.score));
      await store.clearGame();
      if (ref.read(gameModeProvider) == GameMode.daily &&
          snapshot.seed == ref.read(dailyCodeProvider)) {
        await recordDailyResult(store, ref.read(todayProvider), snapshot.score);
        ref.invalidate(dailyStatusProvider);
      }
      ref.invalidate(topScoresProvider);
      ref.invalidate(bestForCodeProvider(snapshot.seed));
      ref.invalidate(bestScoreProvider);
      ref.invalidate(totalsProvider);
    } catch (_) {
      // Ein misslungenes Speichern darf die laufende Runde nicht stoppen.
    }
  }
}
