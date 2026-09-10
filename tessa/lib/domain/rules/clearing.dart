import '../model/board.dart';
import '../model/cell.dart';

/// Ergebnis einer Aufloesung: das geraeumte Brett und welche Linien fielen.
class ClearResult {
  const ClearResult({
    required this.board,
    required this.rows,
    required this.columns,
  });

  final Board board;
  final List<int> rows;
  final List<int> columns;

  int get lineCount => rows.length + columns.length;

  bool get didClear => lineCount > 0;
}

/// Loest alle vollen Reihen und Spalten auf.
///
/// Reihen und Spalten werden gemeinsam ermittelt und erst danach geraeumt:
/// eine Spalte, die nur durch das Raeumen einer Reihe unvollstaendig wuerde,
/// zaehlt im selben Zug trotzdem mit.
ClearResult resolveLines(Board board) {
  final rows = <int>[];
  final columns = <int>[];
  for (var i = 0; i < Board.size; i++) {
    if (board.isRowFull(i)) rows.add(i);
    if (board.isColumnFull(i)) columns.add(i);
  }
  if (rows.isEmpty && columns.isEmpty) {
    return ClearResult(board: board, rows: const [], columns: const []);
  }
  final cells = <Cell>[];
  for (final y in rows) {
    for (var x = 0; x < Board.size; x++) {
      cells.add(Cell(x, y));
    }
  }
  for (final x in columns) {
    for (var y = 0; y < Board.size; y++) {
      cells.add(Cell(x, y));
    }
  }
  return ClearResult(
    board: board.clear(cells),
    rows: List<int>.unmodifiable(rows),
    columns: List<int>.unmodifiable(columns),
  );
}
