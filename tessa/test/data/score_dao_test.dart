import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/data/database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  test('ohne gespielte Runde ist die Liste leer', () async {
    final database = await openMemory();
    addTearDown(database.close);

    expect(await database.scores.top(), isEmpty);
    expect(await database.scores.best(), 0);
  });

  test('sortiert die besten Runden nach oben', () async {
    final database = await openMemory();
    addTearDown(database.close);

    await database.scores.add(score: 120, seed: 1);
    await database.scores.add(score: 4300, seed: 2);
    await database.scores.add(score: 900, seed: 3);

    final top = await database.scores.top();
    expect(top.map((entry) => entry.score), [4300, 900, 120]);
    expect(top.first.seed, 2, reason: 'der Seed gehoert zur Runde');
    expect(await database.scores.best(), 4300);
  });

  test('bei Gleichstand steht die juengere Runde vorn', () async {
    final database = await openMemory();
    addTearDown(database.close);

    final alt = DateTime(2026, 1, 1);
    final neu = DateTime(2026, 6, 1);
    await database.scores.add(score: 500, seed: 10, playedAt: alt);
    await database.scores.add(score: 500, seed: 20, playedAt: neu);

    final top = await database.scores.top();
    expect(top.map((entry) => entry.seed), [20, 10]);
    expect(top.first.playedAt, neu);
  });

  test('gibt hoechstens so viele Eintraege wie verlangt', () async {
    final database = await openMemory();
    addTearDown(database.close);

    for (var i = 0; i < 15; i++) {
      await database.scores.add(score: i * 10, seed: i);
    }
    expect((await database.scores.top()).length, 10);
    expect((await database.scores.top(limit: 3)).length, 3);
    expect((await database.scores.top(limit: 3)).first.score, 140);
  });
}
