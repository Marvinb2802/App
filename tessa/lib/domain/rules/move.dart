import '../generation/piece_sequence.dart';
import '../model/board.dart';
import '../model/game_state.dart';
import 'clearing.dart';
import 'game_over.dart';
import 'placement.dart';
import 'scoring.dart';

/// Startet eine Runde mit [seed].
GameState startGame(int seed) {
  return GameState(
    seed: seed,
    handIndex: 0,
    board: Board.empty(),
    hand: PieceSequence(seed).handAt(0),
    score: 0,
    combo: minCombo,
    undosLeft: GameState.undosPerRound,
    isOver: false,
  );
}

/// Ein vollstaendiger Zug: Teil aus [slot] auf ([x], [y]) legen, aufloesen,
/// bewerten, Hand nachfuellen, Spielende pruefen.
///
/// Wirft, wenn der Zug nicht erlaubt ist — vorher mit [canPlaceFromHand] pruefen.
GameState applyMove(
  GameState state, {
  required int slot,
  required int x,
  required int y,
}) {
  if (state.isOver) {
    throw StateError('Die Runde ist vorbei');
  }
  final piece = state.hand.pieceAt(slot);
  if (piece == null) {
    throw ArgumentError('Platz $slot ist leer');
  }

  final cleared = resolveLines(place(state.board, piece, x, y));
  final points = scoreForMove(
    placedCells: piece.cellCount,
    clearedLines: cleared.lineCount,
    combo: state.combo,
  );

  var hand = state.hand.withoutSlot(slot);
  var handIndex = state.handIndex;
  // Nachschub erst, wenn alle drei Teile platziert sind.
  if (hand.isEmpty) {
    handIndex += 1;
    hand = PieceSequence(state.seed).handAt(handIndex);
  }

  return state.copyWith(
    board: cleared.board,
    hand: hand,
    handIndex: handIndex,
    score: state.score + points,
    combo: nextCombo(state.combo, cleared.lineCount),
    isOver: isGameOver(cleared.board, hand),
    lastMove: MoveOutcome(
      placedCells: piece.cellCount,
      clearedRows: cleared.rows,
      clearedColumns: cleared.columns,
      appliedCombo: state.combo,
      points: points,
    ),
  );
}

/// Passt das Teil aus [slot] auf ([x], [y])?
bool canPlaceFromHand(GameState state, int slot, int x, int y) {
  final piece = state.hand.pieceAt(slot);
  if (piece == null || state.isOver) return false;
  return canPlace(state.board, piece, x, y);
}

/// Nimmt einen Zug zurueck: [previous] wird vollstaendig wiederhergestellt —
/// Brett, Hand, Punkte, Combo und Position in der Steinsequenz — und ein
/// Undo-Versuch wird verbraucht.
///
/// Der Versuchszaehler kommt bewusst aus [current], nicht aus [previous]: sonst
/// wuerde jedes Undo seinen eigenen Verbrauch mit zuruecknehmen.
GameState applyUndo(GameState current, GameState previous) {
  if (!current.canUndo) {
    throw StateError('Keine Undo-Versuche mehr uebrig');
  }
  return previous.copyWith(undosLeft: current.undosLeft - 1);
}
