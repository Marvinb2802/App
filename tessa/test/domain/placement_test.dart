import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/placement.dart';

void main() {
  final square = PieceCatalog.byId('square2');
  final line5 = PieceCatalog.byId('line5h');

  test('ein Teil passt auf ein freies Feld', () {
    expect(canPlace(Board.empty(), square, 0, 0), isTrue);
    expect(canPlace(Board.empty(), square, 6, 6), isTrue);
  });

  test('ein Teil darf nicht ueber den Rand ragen', () {
    expect(canPlace(Board.empty(), square, 7, 0), isFalse);
    expect(canPlace(Board.empty(), line5, 4, 0), isFalse);
    expect(canPlace(Board.empty(), line5, 3, 0), isTrue);
  });

  test('ein Teil darf nicht ueberlappen', () {
    final board = Board.empty().fill(const [Cell(1, 1)]);
    expect(canPlace(board, square, 0, 0), isFalse);
    expect(canPlace(board, square, 2, 2), isTrue);
  });

  test('place belegt genau die Zellen des Teils', () {
    final board = place(Board.empty(), square, 3, 4);
    expect(board.filledCount, 4);
    for (final cell in const [Cell(3, 4), Cell(4, 4), Cell(3, 5), Cell(4, 5)]) {
      expect(board.isFilled(cell.x, cell.y), isTrue, reason: '$cell');
    }
  });

  test('place wirft, wenn der Zug nicht erlaubt ist', () {
    expect(() => place(Board.empty(), square, 7, 7), throwsArgumentError);
  });

  test('placementsFor zaehlt alle Ankerpunkte', () {
    // 2x2 auf leerem 8x8: 7 x 7 moegliche Ankerpunkte.
    expect(placementsFor(Board.empty(), square).length, 49);
    expect(placementsFor(Board.empty(), line5).length, 4 * 8);
  });

  test('hasAnyPlacement erkennt ein volles Brett', () {
    final full = Board.fromRows(List.filled(8, '########'));
    expect(hasAnyPlacement(full, PieceCatalog.byId('dot')), isFalse);
    expect(hasAnyPlacement(Board.empty(), PieceCatalog.byId('dot')), isTrue);
  });
}
