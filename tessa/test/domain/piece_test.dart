import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/piece.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

void main() {
  group('Piece', () {
    test('normalisiert auf die linke obere Ecke', () {
      final piece = Piece.fromCells('test', const [Cell(5, 7), Cell(6, 7)]);
      expect(piece.cells, containsAll(const [Cell(0, 0), Cell(1, 0)]));
      expect(piece.width, 2);
      expect(piece.height, 1);
    });

    test('liest ein Muster ein', () {
      final piece = Piece.fromPattern('corner', const ['#..', '###']);
      expect(piece.cellCount, 4);
      expect(piece.width, 3);
      expect(piece.height, 2);
      expect(piece.cells, contains(const Cell(0, 0)));
      expect(piece.cells, isNot(contains(const Cell(1, 0))));
    });

    test('braucht mindestens eine Zelle', () {
      expect(() => Piece.fromPattern('leer', const ['...']), throwsArgumentError);
    });
  });

  group('PieceCatalog', () {
    test('hat eindeutige Kennungen', () {
      final ids = PieceCatalog.pieces.map((piece) => piece.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('jedes Teil passt aufs Brett und hat ein positives Gewicht', () {
      for (final entry in PieceCatalog.entries) {
        expect(entry.weight, greaterThan(0), reason: entry.piece.id);
        expect(entry.piece.width, lessThanOrEqualTo(Board.size));
        expect(entry.piece.height, lessThanOrEqualTo(Board.size));
        expect(entry.piece.cellCount, greaterThan(0));
      }
    });

    test('das Gesamtgewicht ist die Summe der Einzelgewichte', () {
      final sum = PieceCatalog.entries
          .fold<int>(0, (total, entry) => total + entry.weight);
      expect(PieceCatalog.totalWeight, sum);
    });

    test('findet Teile ueber ihre Kennung', () {
      expect(PieceCatalog.byId('square2').cellCount, 4);
      expect(() => PieceCatalog.byId('gibtesnicht'), throwsArgumentError);
    });
  });
}
