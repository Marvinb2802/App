import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/daily_goal.dart';
import 'package:tessa/application/round_log.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

void main() {
  final dot = PieceCatalog.byId('dot');

  GameState mitPunkten(int score) => GameState(
        seed: 1,
        handIndex: 0,
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        score: score,
        combo: 1,
        undosLeft: 3,
        isOver: false,
      );

  MoveRecord zug({int lines = 0, int combo = 1}) => MoveRecord(
        index: 1,
        clearedLines: lines,
        bestLines: lines,
        points: 10,
        combo: combo,
      );

  test('derselbe Tag ergibt immer dasselbe Ziel', () {
    final a = goalForDate(DateTime(2026, 9, 10));
    final b = goalForDate(DateTime(2026, 9, 10, 22));
    expect(a.kind, b.kind);
    expect(a.target, b.target);
  });

  test('verschiedene Tage bringen Abwechslung', () {
    final ziele = {
      for (var tag = 1; tag <= 30; tag++)
        '${goalForDate(DateTime(2026, 9, tag)).kind}'
            '${goalForDate(DateTime(2026, 9, tag)).target}',
    };
    expect(ziele.length, greaterThan(2));
  });

  test('jedes Ziel hat einen verstaendlichen Text', () {
    for (var tag = 1; tag <= 20; tag++) {
      final text = goalForDate(DateTime(2026, 9, tag)).text;
      expect(text, isNotEmpty);
      expect(text.length, greaterThan(10));
    }
  });

  test('Linienziel zaehlt nur einen einzigen Zug', () {
    const ziel = DailyGoal(GoalKind.linesInOneMove, 3);
    final knapp = RoundLog([zug(lines: 2), zug(lines: 2)]);
    final geschafft = RoundLog([zug(lines: 1), zug(lines: 3)]);

    expect(ziel.reachedBy(knapp, mitPunkten(0)), isFalse,
        reason: 'zweimal zwei sind nicht drei auf einmal');
    expect(ziel.reachedBy(geschafft, mitPunkten(0)), isTrue);
  });

  test('Combo-Ziel schaut auf den hoechsten Stand', () {
    const ziel = DailyGoal(GoalKind.combo, 5);
    expect(ziel.reachedBy(RoundLog([zug(combo: 4)]), mitPunkten(0)), isFalse);
    expect(
      ziel.reachedBy(RoundLog([zug(combo: 5), zug(combo: 1)]), mitPunkten(0)),
      isTrue,
    );
  });

  test('Punkteziel schaut auf den Spielstand', () {
    const ziel = DailyGoal(GoalKind.score, 1500);
    expect(ziel.reachedBy(RoundLog.empty, mitPunkten(1499)), isFalse);
    expect(ziel.reachedBy(RoundLog.empty, mitPunkten(1500)), isTrue);
  });
}
