import 'piece.dart';

/// Ein Teil mit seinem Ziehgewicht.
class WeightedPiece {
  const WeightedPiece(this.piece, this.weight);

  final Piece piece;
  final int weight;
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

  static final List<Piece> pieces =
      List<Piece>.unmodifiable([for (final entry in entries) entry.piece]);

  static final int totalWeight =
      entries.fold(0, (sum, entry) => sum + entry.weight);

  static Piece byId(String id) =>
      pieces.firstWhere((piece) => piece.id == id,
          orElse: () => throw ArgumentError('Unbekanntes Teil: $id'));
}
