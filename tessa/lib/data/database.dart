import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'game_dao.dart';
import 'score_dao.dart';
import 'settings_repository.dart';

/// Aktuelle Schema-Version. Bei jeder Aenderung erhoehen und in
/// [_upgradeSchema] den Weg von der alten Version beschreiben.
const int schemaVersion = 1;

/// Die laufende Partie — hoechstens eine Zeile.
const String tableRunningGame = 'running_game';

/// Abgeschlossene Runden fuer die Bestenliste.
const String tableScores = 'scores';

/// Einstellungen als Schluessel-Wert-Paare.
const String tableSettings = 'settings';

/// Oeffnet die Datenbank und legt sie beim ersten Start an.
///
/// [factory] und [path] sind fuer Tests gedacht: mit `databaseFactoryFfi` und
/// `inMemoryDatabasePath` laeuft alles ohne Geraet.
Future<Database> openTessaDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  final effectiveFactory = factory ?? databaseFactory;
  final effectivePath =
      path ?? p.join(await effectiveFactory.getDatabasesPath(), 'tessa.db');
  return effectiveFactory.openDatabase(
    effectivePath,
    options: OpenDatabaseOptions(
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    ),
  );
}

Future<void> _createSchema(Database db, int version) async {
  await db.execute('''
    CREATE TABLE $tableRunningGame (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      seed INTEGER NOT NULL,
      hand_index INTEGER NOT NULL,
      board TEXT NOT NULL,
      hand TEXT NOT NULL,
      score INTEGER NOT NULL,
      combo INTEGER NOT NULL,
      undos_left INTEGER NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE $tableScores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      score INTEGER NOT NULL,
      seed INTEGER NOT NULL,
      played_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
      'CREATE INDEX scores_by_score ON $tableScores (score DESC, played_at DESC)');
  await db.execute('''
    CREATE TABLE $tableSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
}

Future<void> _upgradeSchema(Database db, int from, int to) async {
  // Noch keine zweite Version. Hier stehen spaeter die Schritte von einer
  // Version zur naechsten, einzeln und in Reihenfolge.
}

/// Die geoeffnete Datenbank samt ihren Zugriffsklassen.
class TessaDatabase {
  TessaDatabase(this.db)
      : games = GameDao(db),
        scores = ScoreDao(db),
        settings = SettingsRepository(db);

  static Future<TessaDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async =>
      TessaDatabase(await openTessaDatabase(factory: factory, path: path));

  final Database db;
  final GameDao games;
  final ScoreDao scores;
  final SettingsRepository settings;

  Future<void> close() => db.close();
}
