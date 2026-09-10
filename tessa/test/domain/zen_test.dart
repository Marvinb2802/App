import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/generation/piece_sequence.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/zen.dart';

void main() {
  final square = PieceCatalog.byId('square2');

  GameState zustand({
    required Board board,
    required Hand hand,
    bool isOver = true,
    int seed = 1,
    int handIndex = 0,
  }) =>
      GameState(
        seed: seed,
        handIndex: handIndex,
        board: board,
        hand: hand,
        score: 500,
        combo: 1,
        undosLeft: 3,
        isOver: isOver,
      );

  test('ruehrt eine laufende Runde nicht an', () {
    final laeuft = zustand(
      board: Board.empty(),
      hand: Hand.of([square, square, square]),
      isOver: false,
    );
    expect(rescue(laeuft), same(laeuft));
  });

  test('holt die naechste Hand aus der Steinfolge', () {
    // Ein Brett, auf das nur noch ein einzelner Punkt passt.
    final brett = Board.fromRows(const [
      '########',
      '########',
      '########',
      '########',
      '########',
      '########',
      '########',
      '#######.',
    ]);

    // Ein Spielcode, dessen naechste Hand einen Punkt enthaelt.
    var seed = 1;
    while (!PieceSequence(seed)
        .handAt(1)
        .remainingPieces
        .any((piece) => piece.id == 'dot')) {
      seed += 1;
    }

    final gerettet = rescue(zustand(
      board: brett,
      hand: Hand.of([square, square, square]),
      seed: seed,
    ));

    expect(gerettet.isOver, isFalse);
    expect(gerettet.handIndex, 1, reason: 'weitergezogen, nicht neu gewuerfelt');
    expect(gerettet.hand, equals(PieceSequence(seed).handAt(1)));
    expect(gerettet.board, equals(brett), reason: 'das Brett bleibt stehen');
    expect(gerettet.score, 500, reason: 'die Rettung gibt keine Punkte');
  });

  test('raeumt notfalls, wenn gar nichts mehr geht', () {
    final voll = Board.fromRows(List.filled(8, '########'));
    final gerettet = rescue(zustand(
      board: voll,
      hand: Hand.of([square, square, square]),
    ));

    expect(gerettet.board.filledCount, lessThan(Board.cellCount));
    expect(gerettet.isOver, isFalse);
    expect(gerettet.handIndex, greaterThan(0));
  });

  test('bleibt beim selben Spielcode', () {
    final voll = Board.fromRows(List.filled(8, '########'));
    final gerettet = rescue(zustand(
      board: voll,
      hand: Hand.of([square, square, square]),
      seed: 99,
    ));
    expect(gerettet.seed, 99);
  });
}
