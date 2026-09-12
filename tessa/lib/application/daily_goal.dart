import '../domain/generation/seeded_random.dart';
import '../domain/model/game_state.dart';
import 'daily.dart';
import 'round_log.dart';

/// Was fuer eine Aufgabe der Tag stellt.
enum GoalKind {
  /// So viele Linien in einem einzigen Zug.
  linesInOneMove,

  /// Diesen Combo-Stand erreichen.
  combo,

  /// Diese Punktzahl erreichen.
  score,

  /// So viele Linien in der ganzen Runde auflösen.
  totalLines,
}

/// Das Ziel des Tages — zusaetzlich zur Punktjagd.
class DailyGoal {
  const DailyGoal(this.kind, this.target);

  final GoalKind kind;
  final int target;

  String get text => switch (kind) {
        GoalKind.linesInOneMove => '$target Linien in einem Zug auflösen',
        GoalKind.combo => 'Combo $target erreichen',
        GoalKind.score => '$target Punkte erreichen',
        GoalKind.totalLines => '$target Linien auflösen',
      };

  bool reachedBy(RoundLog log, GameState state) => switch (kind) {
        GoalKind.linesInOneMove => log.bestClear >= target,
        GoalKind.combo => log.bestCombo >= target,
        GoalKind.score => state.score >= target,
        GoalKind.totalLines => log.totalLines >= target,
      };
}

const List<DailyGoal> _auswahl = [
  DailyGoal(GoalKind.linesInOneMove, 2),
  DailyGoal(GoalKind.linesInOneMove, 3),
  DailyGoal(GoalKind.linesInOneMove, 4),
  DailyGoal(GoalKind.combo, 3),
  DailyGoal(GoalKind.combo, 4),
  DailyGoal(GoalKind.combo, 5),
  DailyGoal(GoalKind.combo, 6),
  DailyGoal(GoalKind.score, 800),
  DailyGoal(GoalKind.score, 1500),
  DailyGoal(GoalKind.score, 2500),
  DailyGoal(GoalKind.score, 4000),
  DailyGoal(GoalKind.totalLines, 6),
  DailyGoal(GoalKind.totalLines, 10),
  DailyGoal(GoalKind.totalLines, 15),
];

/// Das Ziel des Tages, aus dem Datum abgeleitet — fuer alle dasselbe.
///
/// Der Griff in die Liste haengt nur vom Datum ab, an nichts sonst; damit
/// bleibt auch das Ziel nachrechenbar (siehe Fairness-Garantie in CLAUDE.md).
DailyGoal goalForDate(DateTime date) {
  final random = SeededRandom(codeForDate(date) ^ 0x7A11);
  return _auswahl[random.nextIntBelow(_auswahl.length)];
}
