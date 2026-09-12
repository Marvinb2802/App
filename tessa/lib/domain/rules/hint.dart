import '../model/board.dart';
import '../model/cell.dart';
import '../model/hand.dart';
import 'clearing.dart';
import 'placement.dart';

/// Ein Zugvorschlag: welches Teil wohin.
class Hint {
  const Hint({
    required this.slot,
    required this.at,
    required this.clearedLines,
  });

  final int slot;
  final Cell at;

  /// Wie viele Linien dieser Zug aufloesen wuerde.
  final int clearedLines;
}

/// Sucht den besten Zug: moeglichst viele Linien auf einmal.
///
/// Bei Gleichstand gewinnt der zuerst gefundene Zug — die Suche laeuft in
/// fester Reihenfolge, damit derselbe Spielstand immer denselben Vorschlag
/// ergibt. Gibt null zurueck, wenn nichts mehr passt.
Hint? findHint(Board board, Hand hand) {
  Hint? best;
  for (var slot = 0; slot < Hand.slotCount; slot++) {
    final piece = hand.pieceAt(slot);
    if (piece == null) continue;
    for (final at in placementsFor(board, piece)) {
      final lines = resolveLines(place(board, piece, at.x, at.y)).lineCount;
      if (best == null || lines > best.clearedLines) {
        best = Hint(slot: slot, at: at, clearedLines: lines);
      }
    }
  }
  return best;
}
