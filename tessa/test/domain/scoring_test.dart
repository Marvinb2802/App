import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/rules/scoring.dart';

void main() {
  group('Punkte', () {
    test('ohne Aufloesung zaehlen nur die platzierten Zellen', () {
      expect(scoreForMove(placedCells: 4, clearedLines: 0, combo: 5), 4);
    });

    test('eine Linie bei Combo 1 bringt 10 Punkte plus die Zellen', () {
      expect(scoreForMove(placedCells: 3, clearedLines: 1, combo: 1), 3 + 10);
    });

    test('die Linienzahl geht quadratisch ein', () {
      expect(scoreForMove(placedCells: 0, clearedLines: 2, combo: 1), 40);
      expect(scoreForMove(placedCells: 0, clearedLines: 3, combo: 1), 90);
    });

    test('die Combo geht linear ein', () {
      expect(scoreForMove(placedCells: 0, clearedLines: 2, combo: 3), 120);
      expect(scoreForMove(placedCells: 1, clearedLines: 3, combo: 9), 1 + 810);
    });
  });

  group('Combo', () {
    test('startet bei 1 und steigt je Zug mit Aufloesung um 1', () {
      expect(minCombo, 1);
      expect(nextCombo(1, 1), 2);
      expect(nextCombo(2, 1), 3);
    });

    test('steigt einmal je Zug, nicht je Linie', () {
      expect(nextCombo(1, 3), 2);
      expect(nextCombo(4, 8), 5);
    });

    test('endet bei 9', () {
      expect(maxCombo, 9);
      expect(nextCombo(9, 1), 9);
      expect(nextCombo(8, 2), 9);
    });

    test('faellt bei einem Zug ohne Aufloesung auf 1 zurueck', () {
      expect(nextCombo(9, 0), 1);
      expect(nextCombo(1, 0), 1);
    });
  });
}
