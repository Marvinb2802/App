import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/ui/screens/game_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';
import 'package:tessa/ui/widgets/board_view.dart';

import 'fake_sound.dart';

/// Ein Controller, der mit einem vorgegebenen Spielstand startet — damit sich
/// auch Zustaende zeigen lassen, die man sonst erst erspielen muesste.
class FixedGame extends GameController {
  FixedGame(this.initial);

  final GameState initial;

  @override
  GameState build() => initial;
}

Future<ProviderContainer> pumpGame(
  WidgetTester tester, {
  int seed = 2024,
  GameState? state,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => seed),
        if (state != null)
          gameControllerProvider.overrideWith(() => FixedGame(state)),
      ],
      // Direkt der Spielbildschirm: der Einstieg der App ist der
      // Startbildschirm, hier geht es aber um das Spiel selbst.
      child: MaterialApp(
        theme: tessaTheme(),
        home: const GameScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(BoardView)));
}

GameState stateWith({
  required Board board,
  required Hand hand,
  int score = 0,
  int combo = 1,
  int undosLeft = GameState.undosPerRound,
  bool isOver = false,
  int seed = 4711,
}) =>
    GameState(
      seed: seed,
      handIndex: 0,
      board: board,
      hand: hand,
      score: score,
      combo: combo,
      undosLeft: undosLeft,
      isOver: isOver,
    );

/// Der tatsaechliche Vergroesserungsfaktor eines Transform.
///
/// Nicht getMaxScaleOnAxis: das nimmt die Z-Achse mit, die bei Transform.scale
/// immer 1 bleibt — Werte unter 1 waeren dann nicht zu sehen.
double scaleOf(Finder finder, WidgetTester tester) =>
    tester.widget<Transform>(finder).transform.entry(0, 0);

