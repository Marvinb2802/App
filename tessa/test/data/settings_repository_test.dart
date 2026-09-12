import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/data/database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );

  test('liest, schreibt und loescht Werte', () async {
    final database = await openMemory();
    addTearDown(database.close);

    expect(await database.settings.read('ton'), isNull);

    await database.settings.write('ton', 'an');
    expect(await database.settings.read('ton'), 'an');

    await database.settings.write('ton', 'aus');
    expect(await database.settings.read('ton'), 'aus',
        reason: 'derselbe Schluessel wird ueberschrieben, nicht verdoppelt');

    await database.settings.remove('ton');
    expect(await database.settings.read('ton'), isNull);
  });
}
