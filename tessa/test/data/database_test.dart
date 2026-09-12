import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/data/database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  test('legt das Schema beim ersten Oeffnen an', () async {
    final database = await openMemory();
    addTearDown(database.close);

    final tables = await database.db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
    );
    final names = tables.map((row) => row['name']).toSet();

    expect(names, containsAll([tableRunningGame, tableScores, tableSettings]));
    expect(await database.db.getVersion(), schemaVersion);
  });

  test('haelt hoechstens eine laufende Partie', () async {
    final database = await openMemory();
    addTearDown(database.close);

    Future<void> insert() => database.db.insert(tableRunningGame, {
          'id': 1,
          'seed': 1,
          'hand_index': 0,
          'board': '.' * 64,
          'hand': 'dot,dot,dot',
          'score': 0,
          'combo': 1,
          'undos_left': 3,
        });

    await insert();
    // Ohne Konfliktbehandlung ist eine zweite Zeile ein Fehler.
    await expectLater(insert(), throwsA(isA<DatabaseException>()));

    final rows = await database.db.query(tableRunningGame);
    expect(rows.length, 1);
  });
}
