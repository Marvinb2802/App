import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/ui/format.dart';

void main() {
  test('setzt Tausenderpunkte', () {
    expect(zahl(0), '0');
    expect(zahl(7), '7');
    expect(zahl(999), '999');
    expect(zahl(1000), '1.000');
    expect(zahl(12345), '12.345');
    expect(zahl(1234567), '1.234.567');
  });

  test('kommt mit negativen Zahlen zurecht', () {
    expect(zahl(-1500), '-1.500');
  });
}
