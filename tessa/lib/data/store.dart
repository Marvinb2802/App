import '../domain/model/game_state.dart';
import 'database.dart';
import 'score_dao.dart';

/// Was Tessa speichern muss — unabhaengig davon, womit.
///
/// Auf dem Geraet uebernimmt das sqflite ([SqfliteStore]), im Browser gibt es
/// das nicht; dort springt [PrefsStore] ein. Beide koennen dasselbe, damit die
/// Oberflaeche den Unterschied nicht kennen muss.
abstract class TessaStore {
  Future<void> saveGame(GameState state);
  Future<GameState?> loadGame();
  Future<void> clearGame();

  Future<void> addScore({
    required int score,
    required int seed,
    DateTime? playedAt,
  });
  Future<List<ScoreEntry>> topScores({int limit = 10});
  Future<int> bestScore();

  /// Anzahl gespielter Runden und deren Punktsumme — fuer den Durchschnitt.
  Future<({int rounds, int points})> totals();

  Future<String?> readSetting(String key);
  Future<void> writeSetting(String key, String value);

  Future<void> close();
}

/// Speichert in sqflite. Auf Geraeten der Normalfall.
class SqfliteStore implements TessaStore {
  SqfliteStore(this.database);

  final TessaDatabase database;

  @override
  Future<void> saveGame(GameState state) => database.games.save(state);

  @override
  Future<GameState?> loadGame() => database.games.load();

  @override
  Future<void> clearGame() => database.games.clear();

  @override
  Future<void> addScore({
    required int score,
    required int seed,
    DateTime? playedAt,
  }) =>
      database.scores.add(score: score, seed: seed, playedAt: playedAt);

  @override
  Future<List<ScoreEntry>> topScores({int limit = 10}) =>
      database.scores.top(limit: limit);

  @override
  Future<int> bestScore() => database.scores.best();

  @override
  Future<({int rounds, int points})> totals() => database.scores.totals();

  @override
  Future<String?> readSetting(String key) => database.settings.read(key);

  @override
  Future<void> writeSetting(String key, String value) =>
      database.settings.write(key, value);

  @override
  Future<void> close() => database.close();
}
