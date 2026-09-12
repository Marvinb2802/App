import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';

void main() {
  group('Board', () {
    test('ist 8x8 und startet leer', () {
      final board = Board.empty();
      expect(Board.size, 8);
      expect(board.filledCount, 0);
      expect(board.isEmpty, isTrue);
    });

    test('liest ein Zeilenmuster ein', () {
      final board = Board.fromRows(const [
        '########',
        '........',
        '#.......',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      expect(board.isRowFull(0), isTrue);
      expect(board.isRowFull(1), isFalse);
      expect(board.isColumnFull(0), isFalse);
      expect(board.isFilled(0, 2), isTrue);
      expect(board.isFilled(1, 2), isFalse);
      expect(board.filledCount, 9);
    });

    test('erkennt eine volle Spalte', () {
      final board = Board.fromRows(List.filled(8, '#.......'));
      expect(board.isColumnFull(0), isTrue);
      expect(board.isColumnFull(1), isFalse);
    });

    test('fill und clear liefern neue Bretter, das alte bleibt unberuehrt', () {
      final board = Board.empty();
      final filled = board.fill(const [Cell(0, 0), Cell(1, 0)]);
      expect(board.filledCount, 0);
      expect(filled.filledCount, 2);
      expect(filled.clear(const [Cell(0, 0)]).filledCount, 1);
    });

    test('weist Zellen ausserhalb des Rasters zurueck', () {
      expect(() => Board.empty().fill(const [Cell(8, 0)]), throwsArgumentError);
      expect(Board.isInside(7, 7), isTrue);
      expect(Board.isInside(-1, 0), isFalse);
    });

    test('vergleicht ueber die Belegung, nicht die Identitaet', () {
      final a = Board.empty().fill(const [Cell(3, 4)]);
      final b = Board.empty().fill(const [Cell(3, 4)]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(Board.empty())));
    });
  });
}
