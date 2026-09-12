import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/generation/piece_sequence.dart';
import 'package:tessa/domain/model/hand.dart';

List<String> handIds(Hand hand) =>
    hand.slots.map((piece) => piece!.id).toList();

void main() {
  group('PieceSequence', () {
    test('derselbe Seed liefert dieselbe Sequenz', () {
      final a = const PieceSequence(4711);
      final b = const PieceSequence(4711);
      for (var i = 0; i < 30; i++) {
        expect(a.handAt(i), equals(b.handAt(i)), reason: 'Hand $i');
      }
    });

    test('haelt eine bekannte Sequenz fest', () {
      // Referenzlauf: aendert sich diese Liste, aendert sich fuer alle
      // Spielenden die Steinsequenz. Das darf nur bewusst passieren.
      const expected = [
        ['tn', 'line4h', 'line4h'],
        ['corner3sw', 'line2v', 'line5v'],
        ['line5h', 'corner3ne', 'dot'],
        ['line3h', 'line4v', 'tw'],
        ['line4v', 'line2h', 'line2v'],
      ];
      const sequence = PieceSequence(12345);
      for (var i = 0; i < expected.length; i++) {
        expect(handIds(sequence.handAt(i)), expected[i], reason: 'Hand $i');
      }
    });

    test('haengt nicht von der Aufrufreihenfolge ab', () {
      const sequence = PieceSequence(2);
      final direkt = sequence.handAt(7);
      for (var i = 0; i < 7; i++) {
        sequence.handAt(i);
      }
      expect(sequence.handAt(7), equals(direkt));
      expect(const PieceSequence(2).handAt(7), equals(direkt));
    });

    test('verschiedene Seeds liefern verschiedene Sequenzen', () {
      final a = [for (var i = 0; i < 10; i++) handIds(const PieceSequence(1).handAt(i))];
      final b = [for (var i = 0; i < 10; i++) handIds(const PieceSequence(2).handAt(i))];
      expect(a, isNot(equals(b)));
    });

    test('jede Hand hat drei Teile aus dem Katalog', () {
      const sequence = PieceSequence(8);
      for (var i = 0; i < 20; i++) {
        final hand = sequence.handAt(i);
        expect(hand.remainingCount, Hand.slotCount);
        expect(hand.isEmpty, isFalse);
      }
    });

    test('aufeinanderfolgende Haende wiederholen einander nicht verschoben', () {
      // Regression: eine fruehere Ableitung legte die Haende auf dieselbe
      // Zufallskette, nur verschoben — Hand n+1 begann mit den letzten beiden
      // Teilen von Hand n.
      const sequence = PieceSequence(5150);
      var verschoben = 0;
      for (var i = 0; i < 200; i++) {
        final current = handIds(sequence.handAt(i));
        final next = handIds(sequence.handAt(i + 1));
        if (next[0] == current[1] && next[1] == current[2]) verschoben += 1;
      }
      expect(verschoben, lessThan(10),
          reason: 'zufaellig sind wenige Treffer normal, systematisch nicht');
    });

    test('nutzt den Katalog breit', () {
      const sequence = PieceSequence(60);
      final gesehen = <String>{};
      for (var i = 0; i < 200; i++) {
        gesehen.addAll(handIds(sequence.handAt(i)));
      }
      expect(gesehen.length, greaterThan(15));
    });

    test('weist einen negativen Index zurueck', () {
      expect(() => const PieceSequence(1).handAt(-1), throwsArgumentError);
    });
  });
}
