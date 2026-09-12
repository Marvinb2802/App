import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/piece.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

void main() {
  test('eine Vierteldrehung stellt ein liegendes Teil auf', () {
    final liegend = PieceCatalog.byId('line3h'); // 3 breit, 1 hoch
    final stehend = liegend.rotated();

    expect(stehend.width, 1);
    expect(stehend.height, 3);
    expect(stehend.cellCount, 3);
  });

  test('vier Drehungen ergeben wieder das Original', () {
    for (final piece in PieceCatalog.pieces) {
      var gedreht = piece;
      for (var i = 0; i < 4; i++) {
        gedreht = gedreht.rotated();
      }
      expect(gedreht.id, piece.id, reason: piece.id);
      expect(gedreht.cells.toSet(), piece.cells.toSet(), reason: piece.id);
      expect(gedreht.width, piece.width);
      expect(gedreht.height, piece.height);
    }
  });

  test('die Zellenzahl bleibt gleich', () {
    for (final piece in PieceCatalog.pieces) {
      expect(piece.rotated().cellCount, piece.cellCount, reason: piece.id);
    }
  });

  test('die Drehstufe steht in der Kennung', () {
    final piece = PieceCatalog.byId('corner3nw');
    expect(piece.rotation, 0);
    expect(piece.baseId, 'corner3nw');

    final einmal = piece.rotated();
    expect(einmal.id, 'corner3nw@1');
    expect(einmal.rotation, 1);
    expect(einmal.baseId, 'corner3nw');

    expect(einmal.rotated().rotated().rotated().id, 'corner3nw');
  });

  test('ein Quadrat sieht gedreht gleich aus', () {
    final quadrat = PieceCatalog.byId('square2');
    expect(quadrat.rotated().cells.toSet(), quadrat.cells.toSet());
  });

  test('die Drehung geht im Uhrzeigersinn', () {
    // Ein Winkel oben links: (0,0),(1,0),(0,1) wird zu (0,0),(1,0),(1,1).
    final winkel = Piece.fromPattern('test', const ['##', '#.']);
    final gedreht = winkel.rotated();
    expect(gedreht.cells.toSet(), {
      const Cell(0, 0),
      const Cell(1, 0),
      const Cell(1, 1),
    });
  });
}
