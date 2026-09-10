import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/game_state.dart';
import 'game_dao.dart';
import 'score_dao.dart';
import 'store.dart';

/// Speichert in den Einstellungen des Systems — im Browser ist das der
/// lokale Speicher des Browsers.
///
/// Springt ein, wo es sqflite nicht gibt (vor allem im Web), damit auch dort
/// Bestenliste, Serie und Statistik erhalten bleiben.
class PrefsStore implements TessaStore {
  PrefsStore(this._prefs);

  static const String _gameKey = 'tessa.game';
  static const String _scoresKey = 'tessa.scores';
  static const String _settingPrefix = 'tessa.setting.';

  final SharedPreferences _prefs;

  static Future<PrefsStore> open() async =>
      PrefsStore(await SharedPreferences.getInstance());

  @override
  Future<void> saveGame(GameState state) async {
    await _prefs.setString(
      _gameKey,
      jsonEncode({
        'seed': state.seed,
        'handIndex': state.handIndex,
        'board': encodeBoard(state.board),
        'hand': encodeHand(state.hand),
        'score': state.score,
        'combo': state.combo,
        'undosLeft': state.undosLeft,
      }),
    );
  }

  @override
  Future<GameState?> loadGame() async {
    final raw = _prefs.getString(_gameKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final board = decodeBoard(data['board'] as String);
      final hand = decodeHand(data['hand'] as String);
      return GameState(
        seed: data['seed'] as int,
        handIndex: data['handIndex'] as int,
        board: board,
        hand: hand,
        score: data['score'] as int,
        combo: data['combo'] as int,
        undosLeft: data['undosLeft'] as int,
        isOver: false,
      );
    } catch (_) {
      // Beschaedigter Eintrag: lieber neu anfangen als abstuerzen.
      await _prefs.remove(_gameKey);
      return null;
    }
  }

  @override
  Future<void> clearGame() async => _prefs.remove(_gameKey);

  List<Map<String, dynamic>> _scores() {
    final raw = _prefs.getString(_scoresKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> addScore({
    required int score,
    required int seed,
    DateTime? playedAt,
  }) async {
    final entries = _scores();
    final nextId = entries.fold<int>(0, (max, e) {
          final id = e['id'] as int;
          return id > max ? id : max;
        }) +
        1;
    entries.add({
      'id': nextId,
      'score': score,
      'seed': seed,
      'playedAt': (playedAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
    await _prefs.setString(_scoresKey, jsonEncode(entries));
  }

  @override
  Future<List<ScoreEntry>> topScores({int limit = 10}) async {
    final entries = _scores()
      ..sort((a, b) {
        final byScore = (b['score'] as int).compareTo(a['score'] as int);
        return byScore != 0
            ? byScore
            : (b['playedAt'] as int).compareTo(a['playedAt'] as int);
      });
    return [
      for (final entry in entries.take(limit))
        ScoreEntry(
          id: entry['id'] as int,
          score: entry['score'] as int,
          seed: entry['seed'] as int,
          playedAt:
              DateTime.fromMillisecondsSinceEpoch(entry['playedAt'] as int),
        ),
    ];
  }

  @override
  Future<int> bestScore() async {
    final entries = _scores();
    if (entries.isEmpty) return 0;
    return entries
        .map((entry) => entry['score'] as int)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<({int rounds, int points})> totals() async {
    final entries = _scores();
    return (
      rounds: entries.length,
      points: entries.fold<int>(0, (sum, e) => sum + (e['score'] as int)),
    );
  }

  @override
  Future<String?> readSetting(String key) async =>
      _prefs.getString('$_settingPrefix$key');

  @override
  Future<void> writeSetting(String key, String value) async {
    await _prefs.setString('$_settingPrefix$key', value);
  }

  @override
  Future<void> close() async {}
}
