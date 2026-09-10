import 'cell.dart';

/// Das Spielfeld: ein 8x8-Raster aus belegten und freien Zellen.
///
/// Unveraenderlich — jede Aenderung liefert ein neues Board. Das macht Undo
/// trivial (alter Zustand bleibt gueltig) und Tests frei von Seiteneffekten.
class Board {
  Board._(this._cells);

  /// Kantenlaenge des Rasters.
  static const int size = 8;

  /// Anzahl aller Felder.
  static const int cellCount = size * size;

  final List<bool> _cells;

  factory Board.empty() => Board._(List<bool>.filled(cellCount, false));

  /// Baut ein Brett aus [size] Zeilen. '#' bedeutet belegt, jedes andere
  /// Zeichen frei. Vor allem fuer lesbare Tests gedacht.
  factory Board.fromRows(List<String> rows) {
    if (rows.length != size) {
      throw ArgumentError('Ein Brett braucht genau $size Zeilen, hat ${rows.length}');
    }
    final cells = List<bool>.filled(cellCount, false);
    for (var y = 0; y < size; y++) {
      final row = rows[y];
      if (row.length != size) {
        throw ArgumentError('Zeile $y braucht genau $size Zeichen, hat ${row.length}');
      }
      for (var x = 0; x < size; x++) {
        cells[_index(x, y)] = row[x] == '#';
      }
    }
    return Board._(cells);
  }

  static int _index(int x, int y) => y * size + x;

  static bool isInside(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;

  bool isFilled(int x, int y) => _cells[_index(x, y)];

  bool isFree(int x, int y) => !_cells[_index(x, y)];

  int get filledCount => _cells.where((filled) => filled).length;

  bool get isEmpty => filledCount == 0;

  bool isRowFull(int y) {
    for (var x = 0; x < size; x++) {
      if (isFree(x, y)) return false;
    }
    return true;
  }

  bool isColumnFull(int x) {
    for (var y = 0; y < size; y++) {
      if (isFree(x, y)) return false;
    }
    return true;
  }

  /// Belegt [cells]. Zellen ausserhalb des Rasters sind ein Programmierfehler.
  Board fill(Iterable<Cell> cells) => _withCells(cells, true);

  /// Raeumt [cells]. Bereits freie Zellen bleiben frei.
  Board clear(Iterable<Cell> cells) => _withCells(cells, false);

  Board _withCells(Iterable<Cell> cells, bool value) {
    final next = List<bool>.of(_cells);
    for (final cell in cells) {
      if (!isInside(cell.x, cell.y)) {
        throw ArgumentError('Zelle $cell liegt ausserhalb des Rasters');
      }
      next[_index(cell.x, cell.y)] = value;
    }
    return Board._(next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Board) return false;
    for (var i = 0; i < cellCount; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_cells);

  @override
  String toString() => [
        for (var y = 0; y < size; y++)
          [for (var x = 0; x < size; x++) isFilled(x, y) ? '#' : '.'].join(),
      ].join('\n');
}
