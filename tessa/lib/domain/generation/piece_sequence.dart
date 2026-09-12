import '../model/hand.dart';
import '../model/piece.dart';
import '../model/piece_catalog.dart';
import 'seeded_random.dart';

/// Erzeugt die Steinsequenz einer Runde.
///
/// HARTE REGEL (siehe CLAUDE.md, Fairness-Garantie): Die Sequenz haengt
/// ausschliesslich vom Seed und vom laufenden Index ab. Sie darf niemals von
/// Punktzahl, Spieldauer, Brettlage, Geraet, Kaufhistorie oder
/// Werbeinteraktion abhaengen.
///
/// Deshalb ist [handAt] eine reine Funktion zweier Zahlen. Dieser Datei fehlt
/// jeder Zugang zum Spielstand, zur Uhr und zum System — und das soll so
/// bleiben. test/domain/fairness_guard_test.dart wacht darueber.
class PieceSequence {
  const PieceSequence(this.seed, {this.set = PieceSet.standard});

  final int seed;

  /// Welcher Satz Gewichte gezogen wird. Er gehoert zur Runde wie der Seed:
  /// derselbe Code liefert im Hardcore-Modus eine andere — und zwar fuer alle
  /// dieselbe — Folge als im Grundspiel.
  final PieceSet set;

  /// Die [index]-te Hand der Runde. Gleicher Seed und gleicher Index ergeben
  /// immer dieselben drei Teile.
  ///
  /// Eine Runde ist eine einzige Kette von Ziehungen: Hand n benutzt die
  /// Ziehungen 3n bis 3n+2. Haende koennen sich dadurch nicht ueberschneiden,
  /// und der Index allein bestimmt, wo in der Kette gezogen wird.
  Hand handAt(int index) {
    if (index < 0) throw ArgumentError('Index darf nicht negativ sein: $index');
    final random = SeededRandom(seed);
    for (var draw = 0; draw < index * Hand.slotCount; draw++) {
      _drawPiece(random);
    }
    return Hand.of([
      for (var slot = 0; slot < Hand.slotCount; slot++) _drawPiece(random),
    ]);
  }

  /// Zieht ein Teil gemaess der Gewichte des gewaehlten Satzes.
  Piece _drawPiece(SeededRandom random) {
    var roll = random.nextIntBelow(PieceCatalog.totalWeightFor(set));
    for (final entry in PieceCatalog.entriesFor(set)) {
      roll -= entry.weight;
      if (roll < 0) return entry.piece;
    }
    // Unerreichbar: die Gewichte summieren sich zum Gesamtgewicht.
    return PieceCatalog.entriesFor(set).last.piece;
  }
}
