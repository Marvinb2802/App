import '../generation/piece_sequence.dart';
import '../generation/seeded_random.dart';
import '../rules/game_over.dart';
import 'board.dart';
import 'cell.dart';

/// Was ein Level verlangt.
enum LevelGoalKind {
  /// So viele Punkte erreichen.
  score,

  /// So viele Linien insgesamt aufloesen.
  totalLines,

  /// So viele Linien in einem einzigen Zug.
  linesInOneMove,

  /// Diesen Combo-Stand erreichen.
  combo,
}

class LevelGoal {
  const LevelGoal(this.kind, this.target);

  final LevelGoalKind kind;
  final int target;

  String get text => switch (kind) {
        LevelGoalKind.score => '$target Punkte erreichen',
        LevelGoalKind.totalLines => '$target Linien auflösen',
        LevelGoalKind.linesInOneMove =>
          '$target Linien in einem Zug auflösen',
        LevelGoalKind.combo => 'Combo $target erreichen',
      };

  /// Ist das Ziel mit diesen Werten erreicht?
  bool reached({
    required int score,
    required int totalLines,
    required int bestClear,
    required int bestCombo,
  }) =>
      switch (kind) {
        LevelGoalKind.score => score >= target,
        LevelGoalKind.totalLines => totalLines >= target,
        LevelGoalKind.linesInOneMove => bestClear >= target,
        LevelGoalKind.combo => bestCombo >= target,
      };

  String get shortText => switch (kind) {
        LevelGoalKind.score => '$target Punkte',
        LevelGoalKind.totalLines => '$target Linien',
        LevelGoalKind.linesInOneMove => '$target auf einmal',
        LevelGoalKind.combo => 'Combo $target',
      };
}

/// Ein Level: fester Spielcode, festes Ziel, feste Vorbelegung, begrenzte Zuege.
///
/// Alles daran haengt allein an der Nummer — dieselbe Nummer ergibt ueberall
/// dasselbe Level, ohne dass irgendwo eine Liste gepflegt werden muesste.
/// Damit gibt es beliebig viele Level.
class Level {
  const Level({
    required this.number,
    required this.seed,
    required this.goal,
    required this.start,
    required this.moveLimit,
    required this.blockedCells,
  });

  final int number;
  final int seed;
  final LevelGoal goal;

  /// Das Brett zu Beginn — spaetere Level starten teilweise belegt.
  final Board start;

  /// So viele Zuege stehen zur Verfuegung.
  final int moveLimit;

  final int blockedCells;
}

/// Die Stellschrauben der Schwierigkeit — an einer Stelle, damit sich die
/// Kurve nachjustieren laesst.
class LevelTuning {
  LevelTuning._();

  /// Ab hier wird das Brett vorbelegt.
  static const int blocksFrom = 4;

  /// Alle so viele Level eine Zelle mehr.
  static const int blocksEvery = 2;

  /// Mehr wird nie vorbelegt.
  static const int maxBlocks = 20;

  static const int startMoves = 34;
  static const int minMoves = 14;

  /// Alle so viele Level ein Zug weniger.
  static const int movesEvery = 3;
}

int _blockedFor(int number) {
  if (number < LevelTuning.blocksFrom) return 0;
  final wert = (number - LevelTuning.blocksFrom) ~/ LevelTuning.blocksEvery + 1;
  return wert > LevelTuning.maxBlocks ? LevelTuning.maxBlocks : wert;
}

int _movesFor(int number) {
  final wert = LevelTuning.startMoves - (number - 1) ~/ LevelTuning.movesEvery;
  return wert < LevelTuning.minMoves ? LevelTuning.minMoves : wert;
}

/// Die Ziele sind an gemessenem Spiel geeicht: ein Automat, der auf Linien und
/// freies Brett achtet, holt in rund 30 Zuegen etwa 250 Punkte, 11 Linien und
/// Combo 3 bis 5 (siehe test/domain/level_test.dart). Darauf sind die Werte
/// bezogen — nicht geraten.
LevelGoal _goalFor(int number, int moveLimit) {
  final kind = LevelGoalKind.values[(number - 1) % LevelGoalKind.values.length];
  return switch (kind) {
    LevelGoalKind.score => LevelGoal(
        kind,
        _min(moveLimit * (5 + number ~/ 5), moveLimit * 18),
      ),
    LevelGoalKind.totalLines => LevelGoal(
        kind,
        _min(2 + number ~/ 6, moveLimit ~/ 2),
      ),
    LevelGoalKind.linesInOneMove =>
      LevelGoal(kind, 2 + _min(number ~/ 25, 2)),
    LevelGoalKind.combo => LevelGoal(kind, _min(2 + number ~/ 10, 9)),
  };
}

int _min(int a, int b) => a < b ? a : b;

/// Baut das Level mit dieser Nummer.
Level levelFor(int number) {
  if (number < 1) throw ArgumentError('Level beginnen bei 1: $number');

  final seed = 900017 + number * 7919;
  final moveLimit = _movesFor(number);
  final gewuenscht = _blockedFor(number);

  // Sicherheitsnetz: wenn die Vorbelegung die erste Hand blockiert, wird sie
  // schrittweise duenner. Ein Level muss spielbar beginnen.
  var blocked = gewuenscht;
  var start = _startBoard(seed, blocked);
  final ersteHand = PieceSequence(seed).handAt(0);
  while (blocked > 0 && isGameOver(start, ersteHand)) {
    blocked -= 4;
    if (blocked < 0) blocked = 0;
    start = _startBoard(seed, blocked);
  }

  return Level(
    number: number,
    seed: seed,
    goal: _goalFor(number, moveLimit),
    start: start,
    moveLimit: moveLimit,
    blockedCells: blocked,
  );
}

/// Legt [blocked] Zellen vor: nahezu volle Reihen von unten nach oben.
///
/// Zwei frueher gemessene Varianten waren schlechter. Verstreute Einzelzellen
/// zersplittern das Brett, und auch ein loser Sockel liess sich nicht abbauen —
/// in beiden Faellen war bei spaeten Leveln nach vier Zuegen Schluss. Reihen
/// mit wenigen Luecken geben dagegen von Anfang an etwas zu tun.
///
/// Eine Reihe wird nie ganz gefuellt; sie wuerde sich sofort aufloesen.
Board _startBoard(int seed, int blocked) {
  if (blocked <= 0) return Board.empty();
  final random = SeededRandom(seed ^ 0x5EED);
  var board = Board.empty();
  var rest = blocked;

  for (var y = Board.size - 1; y >= 0 && rest > 0; y--) {
    final inDieserReihe = _min(rest, Board.size - 2);
    final spalten = [for (var x = 0; x < Board.size; x++) x];
    // Mischen, damit die Luecken nicht immer an derselben Stelle sitzen.
    for (var i = spalten.length - 1; i > 0; i--) {
      final j = random.nextIntBelow(i + 1);
      final merk = spalten[i];
      spalten[i] = spalten[j];
      spalten[j] = merk;
    }

    board = board.fill([
      for (final x in spalten.take(inDieserReihe)) Cell(x, y),
    ]);
    rest -= inDieserReihe;
  }
  return board;
}
