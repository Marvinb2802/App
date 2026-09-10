import 'cell.dart';

/// Eine Teileform als Menge belegter Zellen, normalisiert auf die linke obere
/// Ecke: die kleinste x- und die kleinste y-Koordinate sind immer 0.
///
/// Teile werden im Grundspiel nicht rotiert. Jede Orientierung ist deshalb ein
/// eigenes Teil im Katalog und hat eine eigene [id].
class Piece {
  const Piece._({
    required this.id,
    required this.cells,
    required this.width,
    required this.height,
  });

  final String id;
  final List<Cell> cells;
  final int width;
  final int height;

  factory Piece.fromCells(String id, Iterable<Cell> cells) {
    final list = cells.toSet().toList();
    if (list.isEmpty) {
      throw ArgumentError('Teil "$id" braucht mindestens eine Zelle');
    }
    var minX = list.first.x;
    var minY = list.first.y;
    var maxX = minX;
    var maxY = minY;
    for (final cell in list) {
      if (cell.x < minX) minX = cell.x;
      if (cell.y < minY) minY = cell.y;
      if (cell.x > maxX) maxX = cell.x;
      if (cell.y > maxY) maxY = cell.y;
    }
    final normalized = [
      for (final cell in list) Cell(cell.x - minX, cell.y - minY),
    ]..sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x);
    return Piece._(
      id: id,
      cells: List<Cell>.unmodifiable(normalized),
      width: maxX - minX + 1,
      height: maxY - minY + 1,
    );
  }

  /// Baut ein Teil aus einem Zeilenmuster: '#' belegt, jedes andere Zeichen frei.
  factory Piece.fromPattern(String id, List<String> rows) {
    final cells = <Cell>[];
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == '#') cells.add(Cell(x, y));
      }
    }
    return Piece.fromCells(id, cells);
  }

  int get cellCount => cells.length;

  @override
  bool operator ==(Object other) => other is Piece && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
