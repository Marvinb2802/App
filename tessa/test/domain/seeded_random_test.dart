import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/generation/seeded_random.dart';

List<int> firstValues(int seed, int count) {
  final random = SeededRandom(seed);
  return [for (var i = 0; i < count; i++) random.nextUint32()];
}

void main() {
  group('SeededRandom', () {
    test('derselbe Seed liefert dieselbe Folge', () {
      expect(firstValues(12345, 50), equals(firstValues(12345, 50)));
    });

    test('verschiedene Seeds liefern verschiedene Folgen', () {
      expect(firstValues(1, 10), isNot(equals(firstValues(2, 10))));
    });

    test('bleibt im Bereich einer vorzeichenlosen 32-Bit-Zahl', () {
      for (final value in firstValues(99, 200)) {
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(0x100000000));
      }
    });

    test('bleibt auch bei Seed 0 in Bewegung', () {
      final values = firstValues(0, 20);
      expect(values.toSet().length, greaterThan(1));
      expect(values.every((value) => value == 0), isFalse);
    });

    test('nextIntBelow bleibt unter der Grenze', () {
      final random = SeededRandom(7);
      for (var i = 0; i < 500; i++) {
        final value = random.nextIntBelow(6);
        expect(value, inInclusiveRange(0, 5));
      }
    });

    test('nextIntBelow verteilt einigermassen gleichmaessig', () {
      final random = SeededRandom(31337);
      final buckets = List<int>.filled(6, 0);
      for (var i = 0; i < 6000; i++) {
        buckets[random.nextIntBelow(6)] += 1;
      }
      for (final count in buckets) {
        expect(count, greaterThan(800), reason: '$buckets');
        expect(count, lessThan(1200), reason: '$buckets');
      }
    });

    test('nextIntBelow braucht eine positive Grenze', () {
      expect(() => SeededRandom(1).nextIntBelow(0), throwsArgumentError);
    });
  });
}
