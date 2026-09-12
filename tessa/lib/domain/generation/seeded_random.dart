/// Deterministischer Zufallszahlengenerator (xorshift32).
///
/// Bewusst selbst implementiert statt Random aus dart:math: dessen Folge ist
/// nicht ueber Dart-Versionen und Plattformen hinweg garantiert gleich. Eine
/// Runde muss sich aber aus ihrem Seed ueberall identisch nachspielen lassen.
///
/// Alle Rechnungen bleiben unter 2^32, damit die Folge auf der VM und im Web
/// dieselbe ist.
class SeededRandom {
  SeededRandom(int seed) : _state = _sanitize(seed);

  static const int _mask = 0xFFFFFFFF;
  static const int _range = 0x100000000;

  /// Ersatzzustand, falls der Seed auf 0 faellt — xorshift bliebe dort haengen.
  static const int _fallbackState = 0x9E3779B9;

  int _state;

  static int _sanitize(int seed) {
    final masked = seed & _mask;
    return masked == 0 ? _fallbackState : masked;
  }

  /// Die naechste Zahl aus [0, 2^32).
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >>> 17;
    x ^= (x << 5) & _mask;
    _state = x;
    return x;
  }

  /// Eine gleichverteilte Zahl aus [0, [bound]).
  ///
  /// Verwirft den Ueberhang am oberen Rand, damit kein Wert bevorzugt wird.
  int nextIntBelow(int bound) {
    if (bound <= 0) throw ArgumentError('Obergrenze muss positiv sein: $bound');
    final limit = _range - (_range % bound);
    int value;
    do {
      value = nextUint32();
    } while (value >= limit);
    return value % bound;
  }
}
