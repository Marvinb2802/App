import '../model/board.dart';
import '../model/cell.dart';
import '../model/piece.dart';

/// Die Zellen, die [piece] belegen wuerde, wenn seine linke obere Ecke auf
/// ([x], [y]) liegt.
Iterable<Cell> cellsAt(Piece piece, int x, int y) =>
    piece.cells.map((cell) => cell.shifted(x, y));

/// Passt [piece] mit der linken oberen Ecke auf ([x], [y])?
bool canPlace(Board board, Piece piece, int x, int y) {
  for (final cell in cellsAt(piece, x, y)) {
    if (!Board.isInside(cell.x, cell.y)) return false;
    if (board.isFilled(cell.x, cell.y)) return false;
  }
  return true;
}

/// Legt [piece] auf das Brett. Vorher [canPlace] pruefen.
Board place(Board board, Piece piece, int x, int y) {
  if (!canPlace(board, piece, x, y)) {
    throw ArgumentError('Teil ${piece.id} passt nicht auf ($x,$y)');
  }
  return board.fill(cellsAt(piece, x, y));
}

/// Alle Ankerpunkte, auf denen [piece] gerade liegen koennte.
Iterable<Cell> placementsFor(Board board, Piece piece) sync* {
  for (var y = 0; y <= Board.size - piece.height; y++) {
    for (var x = 0; x <= Board.size - piece.width; x++) {
      if (canPlace(board, piece, x, y)) yield Cell(x, y);
    }
  }
}

/// Gibt es ueberhaupt noch einen Platz fuer [piece]?
bool hasAnyPlacement(Board board, Piece piece) {
  for (var y = 0; y <= Board.size - piece.height; y++) {
    for (var x = 0; x <= Board.size - piece.width; x++) {
      if (canPlace(board, piece, x, y)) return true;
    }
  }
  return false;
}
