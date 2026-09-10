import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/model/game_state.dart';
import '../domain/rules/move.dart';
import 'providers.dart';

/// Fuehrt die Runde: Zuege, Undo, Neustart.
///
/// Die Regeln selbst stehen in domain/; hier kommt nur die Verwaltung des
/// Verlaufs dazu, den ein Undo braucht.
class GameController extends Notifier<GameState> {
  /// Die letzten Spielstaende, juengster zuletzt.
  ///
  /// Mehr als [GameState.undosPerRound] Eintraege koennen nie gebraucht
  /// werden — weiter zurueck reicht kein Undo.
  final List<GameState> _history = [];

  @override
  GameState build() =>
      ref.read(restoredGameProvider) ??
      startGame(ref.read(seedSourceProvider)());

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
    unawaited(_persist(state));
    return true;
  }

  /// Nimmt den letzten Zug zurueck. Gibt false zurueck, wenn kein Versuch mehr
  /// uebrig ist oder es nichts zurueckzunehmen gibt.
  bool undo() {
    if (!state.canUndo || _history.isEmpty) return false;
    state = applyUndo(state, _history.removeLast());
    unawaited(_persist(state));
    return true;
  }

  /// Startet eine neue Runde. Ohne [seed] kommt ein frischer aus der Quelle.
  void restart({int? seed}) {
    _history.clear();
    state = startGame(seed ?? ref.read(seedSourceProvider)());
    unawaited(_persist(state));
  }

  /// Spielt dieselbe Runde noch einmal: gleicher Seed, gleiche Steinsequenz.
  void replay() => restart(seed: state.seed);

  /// Sichert den Stand, sofern eine Datenbank da ist.
  ///
  /// Eine beendete Runde wandert in die Bestenliste und raeumt die laufende
  /// Partie weg — sie laesst sich nicht fortsetzen.
  Future<void> _persist(GameState snapshot) async {
    final database = ref.read(databaseProvider);
    if (database == null) return;
    try {
      if (snapshot.isOver) {
        await database.scores.add(score: snapshot.score, seed: snapshot.seed);
        await database.games.clear();
      } else {
        await database.games.save(snapshot);
      }
    } catch (_) {
      // Ein misslungenes Speichern darf die laufende Runde nicht stoppen.
    }
  }

  void _remember(GameState snapshot) {
    _history.add(snapshot);
    if (_history.length > GameState.undosPerRound) {
      _history.removeAt(0);
    }
  }
}
