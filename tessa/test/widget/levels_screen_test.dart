import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/level_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/data/prefs_store.dart';
import 'package:tessa/ui/screens/game_screen.dart';
import 'package:tessa/ui/screens/levels_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> speicherMit(int geschafft) async {
    SharedPreferences.setMockInitialValues(
      geschafft == 0 ? {} : {'tessa.setting.levels.done': '$geschafft'},
    );
    return PrefsStore.open();
  }

  Future<ProviderContainer> pumpLevels(
    WidgetTester tester, {
    int geschafft = 0,
  }) async {
    final store = await speicherMit(geschafft);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          seedSourceProvider.overrideWithValue(() => 1),
          storeProvider.overrideWithValue(store),
        ],
        child: MaterialApp(theme: tessaTheme(), home: const LevelsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(LevelsScreen)));
  }

  testWidgets('am Anfang ist nur Level 1 offen', (tester) async {
    await pumpLevels(tester);

    expect(find.byKey(const Key('level-1')), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const Key('level-1'))).onTap,
      isNotNull,
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('level-2'))).onTap,
      isNull,
      reason: 'Level 2 ist noch zu',
    );
  });

  testWidgets('geschaffte Level oeffnen das naechste', (tester) async {
    await pumpLevels(tester, geschafft: 5);

    expect(find.text('Geschafft: Level 5'), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const Key('level-6'))).onTap,
      isNotNull,
      reason: 'das naechste ist offen',
    );
    expect(
      tester.widget<InkWell>(find.byKey(const Key('level-7'))).onTap,
      isNull,
    );
  });

  testWidgets('ein Level starten oeffnet das Spiel', (tester) async {
    final container = await pumpLevels(tester);

    await tester.tap(find.byKey(const Key('level-1')));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(container.read(gameModeProvider), GameMode.level);
    expect(container.read(levelProvider).level!.number, 1);
    expect(find.byKey(const Key('level-goal')), findsOneWidget);
    expect(find.byKey(const Key('level-moves')), findsOneWidget);
  });

  testWidgets('die Liste laesst sich verlaengern', (tester) async {
    await pumpLevels(tester);

    // Ohne Blaettern gibt es die spaeteren Level noch nicht.
    expect(find.byKey(const Key('level-100')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('more-levels')),
      300,
    );
    await tester.tap(find.byKey(const Key('more-levels')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('level-100')), 300);
    expect(find.byKey(const Key('level-100')), findsOneWidget);
  });
}
