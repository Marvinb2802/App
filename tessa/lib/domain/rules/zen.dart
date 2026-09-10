import '../generation/piece_sequence.dart';
import '../model/board.dart';
import '../model/cell.dart';
import '../model/game_state.dart';
import 'clearing.dart';
import 'game_over.dart';

/// Rettet eine festgefahrene Runde im Zen-Modus.
///
/// Zuerst wird die naechste Hand aus der Steinfolge geholt — bis zu
/// [maxHands] Mal. Passt danach immer noch nichts, wird die vollste Reihe
/// geraeumt, damit es weitergeht.
///
/// Die Steinfolge bleibt dabei die des Spielcodes: es wird nur weitergezogen,
/// nie neu gewuerfelt. Punkte gibt es fuer die Rettung keine.
GameState rescue(GameState state, {int maxHands = 5}) {
  if (!state.isOver) return state;

  final sequence = PieceSequence(state.seed);
  var handIndex = state.handIndex;
  var hand = state.hand;

  for (var versuch = 0; versuch < maxHands; versuch++) {
    handIndex += 1;
    hand = sequence.handAt(handIndex);
    if (!isGameOver(state.board, hand)) {
      return state.copyWith(hand: hand, handIndex: handIndex, isOver: false);
    }
  }

  // Immer noch nichts: die vollste Reihe raeumen.
  final board = _clearFullestRow(state.board);
  return state.copyWith(
    board: board,
    hand: hand,
    handIndex: handIndex,
    isOver: isGameOver(board, hand),
  );
}

/// Rettet so lange, bis wieder gespielt werden kann.
///
/// Wird fuer das gekaufte Weiterspielen nach dem Ende benutzt.
GameState rescueUntilPlayable(GameState state, {int maxRuns = 5}) {
  var jetzt = state;
  for (var lauf = 0; lauf < maxRuns && jetzt.isOver; lauf++) {
    jetzt = rescue(jetzt);
  }
  return jetzt;
}

Board _clearFullestRow(Board board) {
  var besteReihe = 0;
  var meiste = -1;
  for (var y = 0; y < Board.size; y++) {
    var belegt = 0;
    for (var x = 0; x < Board.size; x++) {
      if (board.isFilled(x, y)) belegt += 1;
    }
    if (belegt > meiste) {
      meiste = belegt;
      besteReihe = y;
    }
  }
  // Ueber das Fuellen und Aufloesen: so bleibt die Regel an einer Stelle.
  final voll = board.fill([
    for (var x = 0; x < Board.size; x++)
      if (!board.isFilled(x, besteReihe)) Cell(x, besteReihe),
  ]);
  return resolveLines(voll).board;
}
