import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/generation/piece_sequence.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/move.dart';
import 'package:tessa/domain/rules/placement.dart';

GameState stateWith({
  required Board board,
  required Hand hand,
  int combo = 1,
  int score = 0,
  int handIndex = 0,
  int undosLeft = GameState.undosPerRound,
  bool isOver = false,
}) {
  return GameState(
    seed: 42,
    handIndex: handIndex,
    board: board,
    hand: hand,
    score: score,
    combo: combo,
    undosLeft: undosLeft,
    isOver: isOver,
  );
}

/// Legt das erste noch vorhandene Teil auf den ersten passenden Platz.
GameState playFirstFit(GameState state) {
  final slot = state.hand.slots.indexWhere((piece) => piece != null);
  final spot = placementsFor(state.board, state.hand.slots[slot]!).first;
  return applyMove(state, slot: slot, x: spot.x, y: spot.y);
}

void main() {
  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  group('startGame', () {
    test('beginnt mit der ersten Hand der Sequenz', () {
      final state = startGame(777);
      expect(state.hand, equals(const PieceSequence(777).handAt(0)));
      expect(state.handIndex, 0);
      expect(state.board.isEmpty, isTrue);
      expect(state.score, 0);
      expect(state.combo, 1);
      expect(state.undosLeft, 3);
      expect(state.isOver, isFalse);
      expect(state.lastMove, isNull);
    });
  });

  group('applyMove', () {
    test('ohne Aufloesung gibt es einen Punkt je Zelle', () {
      final before = stateWith(board: Board.empty(), hand: Hand.of([square, dot, dot]));
      final after = applyMove(before, slot: 0, x: 0, y: 0);
      expect(after.score, 4);
      expect(after.board.filledCount, 4);
      expect(after.hand.pieceAt(0), isNull);
      expect(after.hand.remainingCount, 2);
      expect(after.lastMove!.didClear, isFalse);
    });

    test('eine volle Reihe loest sich auf und zahlt den Linienbonus', () {
      final before = stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
      );
      final after = applyMove(before, slot: 0, x: 7, y: 7);
      expect(after.board.isEmpty, isTrue);
      expect(after.score, 1 + 10);
      expect(after.lastMove!.clearedRows, const [7]);
      expect(after.lastMove!.appliedCombo, 1);
      expect(after.combo, 2, reason: 'der Stand fuer den naechsten Zug');
    });

    test('bewertet mit dem Combo-Stand vor dem Erhoehen', () {
      final before = stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
        combo: 5,
      );
      final after = applyMove(before, slot: 0, x: 7, y: 7);
      expect(after.lastMove!.appliedCombo, 5);
      expect(after.score, 1 + 10 * 1 * 1 * 5);
      expect(after.combo, 6);
    });

    test('ein Zug ohne Aufloesung setzt die Combo zurueck', () {
      final before = stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        combo: 7,
      );
      expect(applyMove(before, slot: 0, x: 0, y: 0).combo, 1);
    });

    test('Nachschub kommt erst, wenn alle drei Teile liegen', () {
      var state = startGame(2024);
      final firstHand = state.hand;

      state = playFirstFit(state);
      expect(state.handIndex, 0);
      expect(state.hand.remainingCount, 2);

      state = playFirstFit(state);
      expect(state.handIndex, 0);
      expect(state.hand.remainingCount, 1);

      state = playFirstFit(state);
      expect(state.handIndex, 1);
      expect(state.hand.remainingCount, 3);
      expect(state.hand, equals(const PieceSequence(2024).handAt(1)));
      expect(state.hand, isNot(equals(firstHand)));
    });

    test('weist einen Zug zurueck, der nicht erlaubt ist', () {
      final state = stateWith(board: Board.empty(), hand: Hand.of([square, dot, dot]));
      expect(() => applyMove(state, slot: 0, x: 7, y: 7), throwsArgumentError);
      expect(() => applyMove(state.copyWith(hand: state.hand.withoutSlot(0)),
          slot: 0, x: 0, y: 0), throwsArgumentError);
      expect(() => applyMove(state.copyWith(isOver: true), slot: 0, x: 0, y: 0),
          throwsStateError);
    });

    test('erkennt das Spielende nach dem Zug', () {
      // Je Reihe und Spalte zwei freie Zellen, nie benachbart: der Punkt
      // schliesst keine Linie, und fuer ein 2x2 ist nirgends Platz.
      final before = stateWith(
        board: Board.fromRows(const [
          '.###.###',
          '#.###.##',
          '##.###.#',
          '###.###.',
          '.###.###',
          '#.###.##',
          '##.###.#',
          '###.###.',
        ]),
        hand: Hand.of([dot, square, square]),
      );
      final after = applyMove(before, slot: 0, x: 0, y: 0);
      expect(after.lastMove!.didClear, isFalse);
      expect(after.isOver, isTrue);
    });
  });

  group('applyUndo', () {
    test('stellt den vorherigen Stand vollstaendig wieder her', () {
      final previous = stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        combo: 4,
        score: 100,
        handIndex: 7,
      );
      final current = stateWith(
        board: Board.fromRows(const [
          '###.....',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
        ]),
        hand: Hand.of([square, square, square]),
        combo: 1,
        score: 260,
        handIndex: 8,
      );

      final undone = applyUndo(current, previous);
      expect(undone.score, 100);
      expect(undone.combo, 4);
      expect(undone.hand, equals(previous.hand));
      expect(undone.board, equals(previous.board));
      expect(undone.handIndex, 7,
          reason: 'die Position in der Steinsequenz gehoert zum Undo');
    });

    test('verbraucht einen Versuch und nimmt ihn nicht mit zurueck', () {
      final previous = stateWith(board: Board.empty(), hand: Hand.of([dot, dot, dot]));
      final current = stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        undosLeft: 3,
      );
      final once = applyUndo(current, previous);
      expect(once.undosLeft, 2);
      expect(applyUndo(once, previous).undosLeft, 1);
      expect(applyUndo(applyUndo(once, previous), previous).undosLeft, 0);
    });

    test('wirft, wenn keine Versuche mehr uebrig sind', () {
      final state = stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        undosLeft: 0,
      );
      expect(state.canUndo, isFalse);
      expect(() => applyUndo(state, state), throwsStateError);
    });
  });
}
