import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/game_over.dart';

void main() {
      const engesBrett = [
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
      ];

  final dot = PieceCatalog.byId('dot');
  final line5 = PieceCatalog.byId('line5h');
  final square3 = PieceCatalog.byId('square3');
  final square2 = PieceCatalog.byId('square2');

  test('leeres Brett ist nie Game over', () {
    expect(isGameOver(Board.empty(), Hand.of([dot, line5, square3])), isFalse);
  });

  test('Game over, wenn kein Teil der Hand mehr passt', () {
    final full = Board.fromRows(List.filled(8, '########'));
    expect(isGameOver(full, Hand.of([dot, line5, square3])), isTrue);
  });

  test('ein einziges passendes Teil verhindert Game over', () {
    final board = Board.fromRows(engesBrett);
    expect(isGameOver(board, Hand.of([line5, square3, square2])), isTrue);
    expect(isGameOver(board, Hand.of([line5, square3, dot])), isFalse);
  });

  test('bereits platzierte Teile zaehlen nicht mehr mit', () {
    // Der Punkt wuerde passen, ist aber schon gelegt.
    final hand = Hand([line5, dot, square3]).withoutSlot(1);
    expect(isGameOver(Board.fromRows(engesBrett), hand), isTrue);
  });

  test('eine leere Hand ist Nachschub, nicht Spielende', () {
    final full = Board.fromRows(List.filled(8, '########'));
    expect(isGameOver(full, Hand(const [null, null, null])), isFalse);
  });
}
