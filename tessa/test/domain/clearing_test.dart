import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/rules/clearing.dart';

void main() {
  test('ohne volle Linie passiert nichts', () {
    final board = Board.fromRows(const [
      '#######.',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final result = resolveLines(board);
    expect(result.didClear, isFalse);
    expect(result.lineCount, 0);
    expect(result.board, equals(board));
  });

  test('eine volle Reihe loest sich auf', () {
    final result = resolveLines(Board.fromRows(const [
      '########',
      '#.......',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]));
    expect(result.rows, const [0]);
    expect(result.columns, isEmpty);
    expect(result.lineCount, 1);
    expect(result.board.filledCount, 1);
    expect(result.board.isFilled(0, 1), isTrue);
  });

  test('Reihe und Spalte zaehlen im selben Zug gemeinsam', () {
    // Reihe 0 ist voll, Spalte 0 ist voll: zwei Linien, nicht eine.
    final result = resolveLines(Board.fromRows(const [
      '########',
      '#.......',
      '#.......',
      '#.......',
      '#.......',
      '#.......',
      '#.......',
      '#.......',
    ]));
    expect(result.rows, const [0]);
    expect(result.columns, const [0]);
    expect(result.lineCount, 2);
    expect(result.board.isEmpty, isTrue);
  });

  test('mehrere Reihen fallen gleichzeitig', () {
    final result = resolveLines(Board.fromRows(const [
      '########',
      '########',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]));
    expect(result.rows, const [0, 1]);
    expect(result.board.isEmpty, isTrue);
  });

  test('ein volles Brett raeumt sich vollstaendig', () {
    final result = resolveLines(Board.fromRows(List.filled(8, '########')));
    expect(result.lineCount, 16);
    expect(result.board.isEmpty, isTrue);
  });
}
