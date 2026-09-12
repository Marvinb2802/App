import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Einstellungen als Schluessel-Wert-Paare.
class SettingsRepository {
  SettingsRepository(this._db);

  final DatabaseExecutor _db;

  Future<String?> read(String key) async {
    final rows = await _db.query(
      tableSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> write(String key, String value) async {
    await _db.insert(
      tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> remove(String key) async {
    await _db.delete(tableSettings, where: 'key = ?', whereArgs: [key]);
  }
}
