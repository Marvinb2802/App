import 'piece.dart';

/// Ein Teil mit seinem Ziehgewicht.
class WeightedPiece {
  const WeightedPiece(this.piece, this.weight);

  final Piece piece;
  final int weight;
}

/// Welcher Satz von Gewichten gezogen wird.
///
/// Die Formen sind in beiden Saetzen dieselben — nur wie oft sie kommen,
/// unterscheidet sich. Das ist die eine Stellschraube fuer Schwierigkeit, die
/// die Fairness-Garantie ausdruecklich erlaubt: global, fuer alle gleich und
/// unabhaengig davon, wie eine einzelne Partie laeuft (siehe CLAUDE.md).
enum PieceSet {
  /// Das Grundspiel.
  standard,

  /// Hardcore: kleine Teile werden selten, sperrige haeufig.
  hardcore,
}

/// Alle Teile des Grundspiels mit ihren Gewichten.
///
/// Der Katalog ist fest im Code und fuer alle Spielenden gleich. Schwierigkeit
/// darf ueber Formen und Gewichte eingestellt werden — aber nur hier, global
/// und seedunabhaengig vom Spielverlauf (siehe Fairness-Garantie in CLAUDE.md).
/// Da nicht rotiert wird, ist jede Orientierung ein eigener Eintrag.
class PieceCatalog {
  PieceCatalog._();

  static final List<WeightedPiece> entries = List<WeightedPiece>.unmodifiable([
    WeightedPiece(Piece.fromPattern('dot', ['#']), 8),

    WeightedPiece(Piece.fromPattern('line2h', ['##']), 10),
    WeightedPiece(Piece.fromPattern('line2v', ['#', '#']), 10),
    WeightedPiece(Piece.fromPattern('line3h', ['###']), 10),
    WeightedPiece(Piece.fromPattern('line3v', ['#', '#', '#']), 10),
    WeightedPiece(Piece.fromPattern('line4h', ['####']), 6),
    WeightedPiece(Piece.fromPattern('line4v', ['#', '#', '#', '#']), 6),
    WeightedPiece(Piece.fromPattern('line5h', ['#####']), 4),
    WeightedPiece(Piece.fromPattern('line5v', ['#', '#', '#', '#', '#']), 4),

    WeightedPiece(Piece.fromPattern('square2', ['##', '##']), 8),
    WeightedPiece(Piece.fromPattern('square3', ['###', '###', '###']), 2),

    WeightedPiece(Piece.fromPattern('corner3ne', ['##', '#.']), 6),
    WeightedPiece(Piece.fromPattern('corner3nw', ['##', '.#']), 6),
    WeightedPiece(Piece.fromPattern('corner3se', ['#.', '##']), 6),
    WeightedPiece(Piece.fromPattern('corner3sw', ['.#', '##']), 6),

    WeightedPiece(Piece.fromPattern('corner5sw', ['#..', '#..', '###']), 3),
    WeightedPiece(Piece.fromPattern('corner5nw', ['###', '#..', '#..']), 3),
    WeightedPiece(Piece.fromPattern('corner5ne', ['###', '..#', '..#']), 3),
    WeightedPiece(Piece.fromPattern('corner5se', ['..#', '..#', '###']), 3),

    WeightedPiece(Piece.fromPattern('sh', ['.##', '##.']), 3),
    WeightedPiece(Piece.fromPattern('zh', ['##.', '.##']), 3),

    WeightedPiece(Piece.fromPattern('tn', ['###', '.#.']), 3),
    WeightedPiece(Piece.fromPattern('ts', ['.#.', '###']), 3),
    WeightedPiece(Piece.fromPattern('tw', ['.#', '##', '.#']), 3),
    WeightedPiece(Piece.fromPattern('te', ['#.', '##', '#.']), 3),
  ]);

  /// Die Gewichte des Hardcore-Modus.
  ///
  /// Dieselben Formen, andere Haeufigkeit: der Punkt und die kurzen Balken —
  /// die Teile, mit denen sich jede Luecke noch schliessen laesst — werden
  /// selten. Haeufig wird, was sperrig ist: lange Balken, das 3x3-Quadrat, die
  /// grossen Winkel und die versetzten Formen.
  static final List<WeightedPiece> hardcoreEntries =
      List<WeightedPiece>.unmodifiable([
    WeightedPiece(byId('dot'), 1),

    WeightedPiece(byId('line2h'), 2),
    WeightedPiece(byId('line2v'), 2),
    WeightedPiece(byId('line3h'), 5),
    WeightedPiece(byId('line3v'), 5),
    WeightedPiece(byId('line4h'), 8),
    WeightedPiece(byId('line4v'), 8),
    WeightedPiece(byId('line5h'), 7),
    WeightedPiece(byId('line5v'), 7),

    WeightedPiece(byId('square2'), 6),
    WeightedPiece(byId('square3'), 7),

    WeightedPiece(byId('corner3ne'), 4),
    WeightedPiece(byId('corner3nw'), 4),
    WeightedPiece(byId('corner3se'), 4),
    WeightedPiece(byId('corner3sw'), 4),

    WeightedPiece(byId('corner5sw'), 8),
    WeightedPiece(byId('corner5nw'), 8),
    WeightedPiece(byId('corner5ne'), 8),
    WeightedPiece(byId('corner5se'), 8),

    WeightedPiece(byId('sh'), 10),
    WeightedPiece(byId('zh'), 10),

    WeightedPiece(byId('tn'), 7),
    WeightedPiece(byId('ts'), 7),
    WeightedPiece(byId('tw'), 7),
    WeightedPiece(byId('te'), 7),
  ]);

  /// Die Gewichte eines Satzes.
  static List<WeightedPiece> entriesFor(PieceSet set) =>
      switch (set) {
        PieceSet.standard => entries,
        PieceSet.hardcore => hardcoreEntries,
      };

  static final Map<PieceSet, int> _totals = {
    for (final set in PieceSet.values)
      set: entriesFor(set).fold(0, (sum, entry) => sum + entry.weight),
  };

  static int totalWeightFor(PieceSet set) => _totals[set]!;

  static final List<Piece> pieces =
      List<Piece>.unmodifiable([for (final entry in entries) entry.piece]);

  static final int totalWeight =
      entries.fold(0, (sum, entry) => sum + entry.weight);

  static Piece byId(String id) =>
      pieces.firstWhere((piece) => piece.id == id,
          orElse: () => throw ArgumentError('Unbekanntes Teil: $id'));
}
