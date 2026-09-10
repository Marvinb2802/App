import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Was in einem einzelnen Zug passiert ist — und was moeglich gewesen waere.
class MoveRecord {
  const MoveRecord({
    required this.index,
    required this.clearedLines,
    required this.bestLines,
    required this.points,
    required this.combo,
  });

  /// Der wievielte Zug der Runde, ab 1.
  final int index;

  final int clearedLines;

  /// Wie viele Linien der beste verfuegbare Zug aufgeloest haette.
  final int bestLines;

  final int points;
  final int combo;

  /// Wie viele Linien liegen geblieben sind.
  int get missedLines => bestLines - clearedLines;
}

/// Der Verlauf einer Runde. Grundlage fuer die Analyse am Ende und fuer die
/// Pruefung des Tagesziels.
class RoundLog {
  const RoundLog(this.moves);

  static const RoundLog empty = RoundLog([]);

  final List<MoveRecord> moves;

  int get moveCount => moves.length;

  /// Die meisten Linien, die in einem einzigen Zug gefallen sind.
  int get bestClear =>
      moves.fold(0, (max, m) => m.clearedLines > max ? m.clearedLines : max);

  /// Der hoechste erreichte Combo-Stand.
  int get bestCombo => moves.fold(0, (max, m) => m.combo > max ? m.combo : max);

  /// Der Zug, bei dem am meisten liegen geblieben ist.
  MoveRecord? get biggestMiss {
    MoveRecord? schlimmster;
    for (final move in moves) {
      if (move.missedLines <= 0) continue;
      if (schlimmster == null || move.missedLines > schlimmster.missedLines) {
        schlimmster = move;
      }
    }
    return schlimmster;
  }

  /// Der beste eigene Zug der Runde.
  MoveRecord? get bestMove {
    MoveRecord? bester;
    for (final move in moves) {
      if (move.clearedLines == 0) continue;
      if (bester == null || move.points > bester.points) bester = move;
    }
    return bester;
  }
}

class RoundLogController extends Notifier<RoundLog> {
  @override
  RoundLog build() => RoundLog.empty;

  void record(MoveRecord move) =>
      state = RoundLog([...state.moves, move]);

  void reset() => state = RoundLog.empty;

  /// Nimmt den letzten Eintrag zurueck — passend zum Undo.
  void undoLast() {
    if (state.moves.isEmpty) return;
    state = RoundLog(state.moves.sublist(0, state.moves.length - 1));
  }
}
