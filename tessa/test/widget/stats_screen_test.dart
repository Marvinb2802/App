import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/sound.dart';

import '../support/fake_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessa/application/daily.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/data/prefs_store.dart';
import 'package:tessa/ui/screens/stats_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> speicher() async {
    SharedPreferences.setMockInitialValues({});
    return PrefsStore.open();
  }

  Future<ProviderContainer> pumpStats(
    WidgetTester tester, {
    PrefsStore? store,
    DateTime? today,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          storeProvider.overrideWithValue(store),
          if (today != null) todayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(theme: tessaTheme(), home: const StatsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(StatsScreen)));
  }

  /// Der Wert einer Statistik-Zeile: die zweite Beschriftung darin.
  String wert(WidgetTester tester, String key) => tester
      .widget<Text>(find
          .descendant(of: find.byKey(Key(key)), matching: find.byType(Text))
          .last)
      .data!;

  testWidgets('ohne gespielte Runde stehen Nullen da', (tester) async {
    await pumpStats(tester, store: await speicher());

    expect(wert(tester, 'stat-rounds'), '0');
    expect(wert(tester, 'stat-best'), '0');
    expect(wert(tester, 'stat-average'), '0');
    expect(find.textContaining('Sobald du eine Runde'), findsOneWidget);
  });

  testWidgets('rechnet Runden, Bestwert und Durchschnitt', (tester) async {
    final store = await speicher();
    await store.addScore(score: 100, seed: 1);
    await store.addScore(score: 300, seed: 2);
    await store.addScore(score: 200, seed: 3);

    await pumpStats(tester, store: store);

    expect(wert(tester, 'stat-rounds'), '3');
    expect(wert(tester, 'stat-best'), '300');
    expect(wert(tester, 'stat-average'), '200');
  });

  testWidgets('zeigt die Serie des Tagesraetsels', (tester) async {
    final store = await speicher();
    await recordDailyResult(store, DateTime(2026, 9, 9), 100);
    await recordDailyResult(store, DateTime(2026, 9, 10), 200);

    await pumpStats(tester, store: store, today: DateTime(2026, 9, 10));

    expect(wert(tester, 'stat-streak'), '2');
  });

  testWidgets('die Vibration laesst sich abschalten', (tester) async {
    final store = await speicher();
    final container = await pumpStats(tester, store: store);

    expect(container.read(hapticsProvider), isTrue);

    await tester.tap(find.byKey(const Key('haptics-switch')));
    await tester.pumpAndSettle();

    expect(container.read(hapticsProvider), isFalse);
    expect(await store.readSetting('haptics'), '0',
        reason: 'die Einstellung ueberlebt den Neustart');
  });
}
