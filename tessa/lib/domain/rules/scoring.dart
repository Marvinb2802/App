/// Kleinster Combo-Stand; auf ihn faellt ein Zug ohne Aufloesung zurueck.
const int minCombo = 1;

/// Obergrenze der Combo.
const int maxCombo = 9;

/// Punkte eines Zuges: 1 je platzierter Zelle, dazu 10 * L * L * Combo, wenn
/// [clearedLines] Linien gleichzeitig fallen.
///
/// [combo] ist der Stand *vor* dem Erhoehen: die erste Aufloesung nach einem
/// Reset zaehlt mit Faktor 1.
int scoreForMove({
  required int placedCells,
  required int clearedLines,
  required int combo,
}) {
  if (clearedLines == 0) return placedCells;
  return placedCells + 10 * clearedLines * clearedLines * combo;
}

/// Der Combo-Stand nach einem Zug.
///
/// Die Combo steigt einmal je Zug mit Aufloesung — nicht je Linie, denn die
/// Linienzahl geht bereits quadratisch in [scoreForMove] ein.
int nextCombo(int combo, int clearedLines) {
  if (clearedLines == 0) return minCombo;
  return combo >= maxCombo ? maxCombo : combo + 1;
}
