import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessa/application/daily.dart';
import 'package:tessa/data/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> leererSpeicher() async {
    SharedPreferences.setMockInitialValues({});
    return PrefsStore.open();
  }

  test('der Spielcode kommt aus dem Datum', () {
    expect(codeForDate(DateTime(2026, 9, 10)), 20260910);
    expect(codeForDate(DateTime(2026, 1, 1)), 20260101);
    expect(codeForDate(DateTime(2025, 12, 31)), 20251231);
  });

  test('derselbe Tag ergibt immer denselben Code', () {
    expect(codeForDate(DateTime(2026, 9, 10, 8, 30)),
        codeForDate(DateTime(2026, 9, 10, 23, 59)));
  });

  test('ohne Speicher gibt es keinen Stand', () async {
    final status = await readDailyStatus(null, DateTime(2026, 9, 10));
    expect(status.playedToday, isFalse);
    expect(status.streak, 0);
  });

  test('das erste Tagesraetsel startet die Serie bei 1', () async {
    final store = await leererSpeicher();
    final heute = DateTime(2026, 9, 10);

    await recordDailyResult(store, heute, 1200);

    final status = await readDailyStatus(store, heute);
    expect(status.playedToday, isTrue);
    expect(status.streak, 1);
    expect(status.lastScore, 1200);
  });

  test('an aufeinanderfolgenden Tagen waechst die Serie', () async {
    final store = await leererSpeicher();
    await recordDailyResult(store, DateTime(2026, 9, 8), 100);
    await recordDailyResult(store, DateTime(2026, 9, 9), 200);
    await recordDailyResult(store, DateTime(2026, 9, 10), 300);

    final status = await readDailyStatus(store, DateTime(2026, 9, 10));
    expect(status.streak, 3);
  });

  test('ein ausgelassener Tag setzt die Serie zurueck', () async {
    final store = await leererSpeicher();
    await recordDailyResult(store, DateTime(2026, 9, 8), 100);
    // Der 9. wird ausgelassen.
    await recordDailyResult(store, DateTime(2026, 9, 10), 300);

    expect((await readDailyStatus(store, DateTime(2026, 9, 10))).streak, 1);
  });

  test('zweimal am selben Tag zaehlt nur einmal', () async {
    final store = await leererSpeicher();
    final heute = DateTime(2026, 9, 10);
    await recordDailyResult(store, heute, 100);
    await recordDailyResult(store, heute, 5000);

    final status = await readDailyStatus(store, heute);
    expect(status.streak, 1);
    expect(status.lastScore, 100, reason: 'der erste Versuch zaehlt');
  });

  test('eine gestern beendete Serie laeuft noch, eine aeltere ist gerissen',
      () async {
    final store = await leererSpeicher();
    await recordDailyResult(store, DateTime(2026, 9, 9), 100);

    expect((await readDailyStatus(store, DateTime(2026, 9, 10))).streak, 1);
    expect((await readDailyStatus(store, DateTime(2026, 9, 10))).playedToday,
        isFalse);
    expect((await readDailyStatus(store, DateTime(2026, 9, 12))).streak, 0,
        reason: 'zwei Tage Pause');
  });

  test('ueber einen Monatswechsel hinweg zaehlt die Serie weiter', () async {
    final store = await leererSpeicher();
    await recordDailyResult(store, DateTime(2026, 8, 31), 100);
    await recordDailyResult(store, DateTime(2026, 9, 1), 200);

    expect((await readDailyStatus(store, DateTime(2026, 9, 1))).streak, 2);
  });
}
