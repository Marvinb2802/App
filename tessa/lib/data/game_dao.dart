import 'package:sqflite/sqflite.dart';

import '../domain/model/board.dart';
import '../domain/model/game_state.dart';
import '../domain/model/hand.dart';
import '../domain/model/piece.dart';
import '../domain/model/piece_catalog.dart';
import '../domain/rules/game_over.dart';
import 'database.dart';

/// Das Brett als 64 Zeichen, zeilenweise: '#' belegt, '.' frei.
String encodeBoard(Board board) => [
      for (var y = 0; y < Board.size; y++)
        for (var x = 0; x < Board.size; x++) board.isFilled(x, y) ? '#' : '.',
    ].join();

Board decodeBoard(String text) {
  if (text.length != Board.cellCount) {
    throw FormatException('Brett braucht ${Board.cellCount} Zeichen', text);
  }
  return Board.fromRows([
    for (var y = 0; y < Board.size; y++)
      text.substring(y * Board.size, (y + 1) * Board.size),
  ]);
}

/// Die Hand als Kennungen, durch Komma getrennt; ein leerer Eintrag steht
/// fuer einen bereits platzierten Platz.
String encodeHand(Hand hand) =>
    hand.slots.map((piece) => piece?.id ?? '').join(',');

Hand decodeHand(String text) {
  final parts = text.split(',');
  if (parts.length != Hand.slotCount) {
    throw FormatException('Hand braucht ${Hand.slotCount} Eintraege', text);
  }
  return Hand([
    for (final part in parts) part.isEmpty ? null : _pieceFromId(part),
  ]);
}

/// Loest eine Kennung auf, auch mit Drehstufe: 'line3h@1' ist das einmal
/// gedrehte Teil aus dem Katalog.
Piece _pieceFromId(String id) {
  final teile = id.split('@');
  var piece = PieceCatalog.byId(teile.first);
  final stufe = teile.length > 1 ? int.tryParse(teile[1]) ?? 0 : 0;
  for (var i = 0; i < stufe; i++) {
    piece = piece.rotated();
  }
  return piece;
}

/// Sichert die laufende Partie und holt sie zurueck.
///
/// Gespeichert wird nur eine *unfertige* Runde. Ist sie vorbei, wandert sie in
/// die Bestenliste und die Zeile wird geloescht.
class GameDao {
  GameDao(this._db);

  final DatabaseExecutor _db;

  Future<void> save(GameState state) async {
    await _db.insert(
      tableRunningGame,
      {
        'id': 1,
        'seed': state.seed,
        'hand_index': state.handIndex,
        'board': encodeBoard(state.board),
        'hand': encodeHand(state.hand),
        'score': state.score,
        'combo': state.combo,
        'undos_left': state.undosLeft,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Die gesicherte Partie, oder null, wenn keine offen ist.
  ///
  /// Der Undo-Verlauf wird bewusst nicht mitgesichert: nach einem Neustart der
  /// App gibt es nichts mehr zurueckzunehmen, die Zahl der Versuche bleibt
  /// aber erhalten.
  Future<GameState?> load() async {
    final rows = await _db.query(tableRunningGame, limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final board = decodeBoard(row['board']! as String);
    final hand = decodeHand(row['hand']! as String);
    return GameState(
      seed: row['seed']! as int,
      handIndex: row['hand_index']! as int,
      board: board,
      hand: hand,
      score: row['score']! as int,
      combo: row['combo']! as int,
      undosLeft: row['undos_left']! as int,
      isOver: isGameOver(board, hand),
    );
  }

  Future<void> clear() async => _db.delete(tableRunningGame);
}
