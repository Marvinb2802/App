import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Eine abgeschlossene Runde in der Bestenliste.
class ScoreEntry {
  const ScoreEntry({
    required this.id,
    required this.score,
    required this.seed,
    required this.playedAt,
  });

  final int id;
  final int score;

  /// Der Seed der Runde — damit sie sich nachspielen laesst.
  final int seed;

  final DateTime playedAt;
}

class ScoreDao {
  ScoreDao(this._db);

  final DatabaseExecutor _db;

  Future<int> add({
    required int score,
    required int seed,
    DateTime? playedAt,
  }) {
    return _db.insert(tableScores, {
      'score': score,
      'seed': seed,
      'played_at': (playedAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  /// Die besten Runden, beste zuerst; bei Gleichstand die juengere zuerst.
  Future<List<ScoreEntry>> top({int limit = 10}) async {
    final rows = await _db.query(
      tableScores,
      orderBy: 'score DESC, played_at DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        ScoreEntry(
          id: row['id']! as int,
          score: row['score']! as int,
          seed: row['seed']! as int,
          playedAt:
              DateTime.fromMillisecondsSinceEpoch(row['played_at']! as int),
        ),
    ];
  }

  /// Der beste Wert zu genau diesem Spielcode, 0 wenn noch nie gespielt.
  Future<int> bestForSeed(int seed) async {
    final rows = await _db.rawQuery(
        'SELECT MAX(score) AS best FROM $tableScores WHERE seed = ?', [seed]);
    return (rows.first['best'] as int?) ?? 0;
  }

  /// Anzahl gespielter Runden und deren Punktsumme.
  Future<({int rounds, int points})> totals() async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) AS runden, COALESCE(SUM(score), 0) AS punkte '
        'FROM $tableScores');
    return (
      rounds: (rows.first['runden'] as int?) ?? 0,
      points: (rows.first['punkte'] as int?) ?? 0,
    );
  }

  /// Die hoechste je erreichte Punktzahl, 0 ohne gespielte Runde.
  Future<int> best() async {
    final rows = await _db.rawQuery('SELECT MAX(score) AS best FROM $tableScores');
    return (rows.first['best'] as int?) ?? 0;
  }
}
