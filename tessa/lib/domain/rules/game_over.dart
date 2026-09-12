import '../model/board.dart';
import '../model/hand.dart';
import 'placement.dart';

/// Game over, wenn kein Teil der verbliebenen Hand mehr irgendwo passt.
///
/// Eine leere Hand ist kein Game over: dort steht der Nachschub an, nicht das
/// Spielende.
bool isGameOver(Board board, Hand hand) {
  if (hand.isEmpty) return false;
  return !hand.remainingPieces.any((piece) => hasAnyPlacement(board, piece));
}
