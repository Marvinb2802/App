import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/data/database.dart';
import 'package:tessa/data/game_dao.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/move.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  group('Kodierung', () {
    test('Brett hin und zurueck', () {
      final board = Board.fromRows(const [
        '#.......',
        '........',
        '..##....',
        '........',
        '........',
        '........',
        '........',
        '.......#',
      ]);
      expect(encodeBoard(board).length, Board.cellCount);
      expect(decodeBoard(encodeBoard(board)), equals(board));
    });

    test('Hand hin und zurueck, auch mit gelegten Teilen', () {
      final hand = Hand([dot, null, square]);
      expect(encodeHand(hand), 'dot,,square2');
      expect(decodeHand(encodeHand(hand)), equals(hand));
    });

    test('weist beschaedigte Daten zurueck', () {
      expect(() => decodeBoard('##'), throwsFormatException);
      expect(() => decodeHand('dot,dot'), throwsFormatException);
      expect(() => decodeHand('dot,dot,gibtesnicht'), throwsArgumentError);
    });
  });

  group('GameDao', () {
    test('ohne gesicherte Partie kommt null zurueck', () async {
      final database = await openMemory();
      addTearDown(database.close);
      expect(await database.games.load(), isNull);
    });

    test('sichert eine Partie und holt sie unveraendert zurueck', () async {
      final database = await openMemory();
      addTearDown(database.close);

      var state = startGame(4711);
      state = applyMove(state, slot: 0, x: 0, y: 0);
      await database.games.save(state);

      final loaded = await database.games.load();
      expect(loaded, isNotNull);
      expect(loaded!.seed, state.seed);
      expect(loaded.handIndex, state.handIndex);
      expect(loaded.board, equals(state.board));
      expect(loaded.hand, equals(state.hand));
      expect(loaded.score, state.score);
      expect(loaded.combo, state.combo);
      expect(loaded.undosLeft, state.undosLeft);
      expect(loaded.isOver, isFalse);
    });

    test('ueberschreibt die vorige Partie, statt eine zweite anzulegen',
        () async {
      final database = await openMemory();
      addTearDown(database.close);

      await database.games.save(startGame(1));
      await database.games.save(startGame(2));

      final rows = await database.db.query(tableRunningGame);
      expect(rows.length, 1);
      expect((await database.games.load())!.seed, 2);
    });

    test('clear raeumt die Partie weg', () async {
      final database = await openMemory();
      addTearDown(database.close);

      await database.games.save(startGame(3));
      await database.games.clear();
      expect(await database.games.load(), isNull);
    });

    test('erkennt beim Laden, dass nichts mehr passt', () async {
      final database = await openMemory();
      addTearDown(database.close);

      // Volles Brett: kein Teil kann mehr gelegt werden.
      await database.games.save(GameState(
        seed: 5,
        handIndex: 2,
        board: Board.fromRows(List.filled(8, '########')),
        hand: Hand.of([square, square, square]),
        score: 500,
        combo: 1,
        undosLeft: 1,
        isOver: false,
      ));

      expect((await database.games.load())!.isOver, isTrue);
    });
  });
}
