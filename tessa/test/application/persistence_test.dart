import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/data/database.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/placement.dart';

/// Wartet, bis das nebenher laufende Sichern durch ist — statt auf eine feste
/// Zeitspanne zu hoffen.
Future<T> eventually<T>(Future<T?> Function() read, {String? reason}) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    final value = await read();
    if (value != null) return value;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(reason ?? 'nichts gesichert');
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  ProviderContainer containerFor(
    TessaDatabase database, {
    int seed = 2024,
    GameState? restored,
  }) =>
      ProviderContainer.test(
        overrides: [
          seedSourceProvider.overrideWithValue(() => seed),
          databaseProvider.overrideWithValue(database),
          restoredGameProvider.overrideWithValue(restored),
        ],
      );

  test('sichert die Partie nach jedem Zug', () async {
    final database = await openMemory();
    addTearDown(database.close);
    final container = containerFor(database);

    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);
    final spot = placementsFor(before.board, before.hand.pieceAt(0)!).first;
    controller.place(slot: 0, x: spot.x, y: spot.y);

    final saved = await eventually(database.games.load);
    final current = container.read(gameControllerProvider);
    expect(saved.board, equals(current.board));
    expect(saved.score, current.score);
    expect(saved.handIndex, current.handIndex);
    expect(saved.hand, equals(current.hand));
  });

  test('setzt eine gesicherte Partie fort statt neu anzufangen', () async {
    final database = await openMemory();
    addTearDown(database.close);

    final unterbrochen = GameState(
      seed: 99,
      handIndex: 3,
      board: Board.fromRows(const [
        '###.....',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]),
      hand: Hand.of([
        PieceCatalog.byId('dot'),
        PieceCatalog.byId('line2h'),
        PieceCatalog.byId('square2'),
      ]),
      score: 640,
      combo: 3,
      undosLeft: 1,
      isOver: false,
    );
    await database.games.save(unterbrochen);

    final restored = await database.games.load();
    final container = containerFor(database, restored: restored);
    final state = container.read(gameControllerProvider);

    expect(state.seed, 99);
    expect(state.score, 640);
    expect(state.combo, 3);
    expect(state.undosLeft, 1);
    expect(state.handIndex, 3);
    expect(state.board.filledCount, 3);
  });

  test('traegt eine beendete Runde in die Bestenliste ein und raeumt auf',
      () async {
    final database = await openMemory();
    addTearDown(database.close);

    // Ein Brett, auf dem nach dem Punkt nichts mehr passt.
    final kurzVorSchluss = GameState(
      seed: 555,
      handIndex: 9,
      board: Board.fromRows(const [
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
      ]),
      hand: Hand.of([
        PieceCatalog.byId('dot'),
        PieceCatalog.byId('square2'),
        PieceCatalog.byId('square2'),
      ]),
      score: 3210,
      combo: 1,
      undosLeft: 3,
      isOver: false,
    );
    await database.games.save(kurzVorSchluss);
    final container = containerFor(database, restored: kurzVorSchluss);

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);
    expect(container.read(gameControllerProvider).isOver, isTrue);

    final top = await eventually(() async {
      final entries = await database.scores.top();
      return entries.isEmpty ? null : entries;
    }, reason: 'die beendete Runde steht nicht in der Bestenliste');
    expect(top.length, 1);
    expect(top.first.score, 3211, reason: 'die letzte Zelle zaehlt noch');
    expect(top.first.seed, 555);
    expect(await database.games.load(), isNull,
        reason: 'eine beendete Runde laesst sich nicht fortsetzen');
  });

  test('ohne Datenbank laeuft das Spiel weiter', () {
    final container = ProviderContainer.test(
      overrides: [seedSourceProvider.overrideWithValue(() => 7)],
    );
    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);
    final spot = placementsFor(before.board, before.hand.pieceAt(0)!).first;

    expect(controller.place(slot: 0, x: spot.x, y: spot.y), isTrue);
    expect(container.read(gameControllerProvider).score, greaterThan(0));
  });
}
