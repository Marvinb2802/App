import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/model/game_state.dart';
import '../domain/rules/move.dart';
import 'daily.dart';
import 'game_mode.dart';
import 'sound.dart';
import 'providers.dart';

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
    _remember(state);
    state = applyMove(state, slot: slot, x: x, y: y);
    ref.read(hintProvider.notifier).hide();
    _feedback(state);
    unawaited(_persist(state));
    return true;
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
    unawaited(_persist(state));
    return true;
  }

  /// Startet eine neue Runde. Ohne [seed] kommt ein frischer Spielcode.
  void restart({int? seed}) {
    _history.clear();
    state = startGame(seed ?? ref.read(seedSourceProvider)());
    ref.read(hintProvider.notifier).reset();
    unawaited(_persist(state));
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
    final store = ref.read(storeProvider);
    if (store == null) return;
    try {
      if (!snapshot.isOver) {
        await store.saveGame(snapshot);
        return;
      }
      await store.addScore(score: snapshot.score, seed: snapshot.seed);
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
