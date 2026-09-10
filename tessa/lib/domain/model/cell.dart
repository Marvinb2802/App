/// Eine Position im Raster. Wird sowohl fuer Brettfelder als auch fuer die
/// Zellen einer Teileform benutzt.
class Cell {
  const Cell(this.x, this.y);

  final int x;
  final int y;

  Cell shifted(int dx, int dy) => Cell(x + dx, y + dy);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x,$y)';
}
