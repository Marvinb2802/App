/// Punktzahlen mit Tausenderpunkten: 12345 wird zu 12.345.
String zahl(int wert) {
  final ziffern = wert.abs().toString();
  final teile = <String>[];
  for (var ende = ziffern.length; ende > 0; ende -= 3) {
    teile.insert(0, ziffern.substring(ende - 3 < 0 ? 0 : ende - 3, ende));
  }
  return '${wert < 0 ? '-' : ''}${teile.join('.')}';
}
