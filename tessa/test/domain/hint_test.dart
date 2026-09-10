import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/hint.dart';

void main() {
  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  test('schlaegt einen Zug vor, der eine Linie aufloest', () {
    final board = Board.fromRows(const [
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '#######.',
    ]);
    final hint = findHint(board, Hand.of([square, dot, square]));

    expect(hint, isNotNull);
    expect(hint!.slot, 1, reason: 'nur der Punkt schliesst die Reihe');
    expect(hint.at, const Cell(7, 7));
    expect(hint.clearedLines, 1);
  });

  test('schlaegt sonst irgendeinen gueltigen Zug vor', () {
    final hint = findHint(Board.empty(), Hand.of([square, dot, dot]));
    expect(hint, isNotNull);
    expect(hint!.clearedLines, 0);
  });

  test('gibt null zurueck, wenn nichts mehr passt', () {
    final voll = Board.fromRows(List.filled(8, '########'));
    expect(findHint(voll, Hand.of([dot, square, square])), isNull);
  });

  test('derselbe Stand ergibt immer denselben Vorschlag', () {
    final board = Board.empty();
    final hand = Hand.of([square, dot, dot]);
    final erster = findHint(board, hand)!;
    final zweiter = findHint(board, hand)!;
    expect(zweiter.slot, erster.slot);
    expect(zweiter.at, erster.at);
  });
}
