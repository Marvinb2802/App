import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessa/application/daily.dart';
import 'package:tessa/data/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> speicher() async {
    SharedPreferences.setMockInitialValues({});
    return PrefsStore.open();
  }

  test('die Woche laeuft von Montag bis Sonntag', () {
    // Der 10.09.2026 ist ein Donnerstag.
    final woche = weekOf(DateTime(2026, 9, 10));

    expect(woche.length, 7);
    expect(woche.first.weekday, DateTime.monday);
    expect(woche.first.day, 7);
    expect(woche.last.weekday, DateTime.sunday);
    expect(woche.last.day, 13);
  });

  test('jeder Tag der Woche fuehrt zur selben Woche', () {
    final vomMontag = weekOf(DateTime(2026, 9, 7));
    final vomSonntag = weekOf(DateTime(2026, 9, 13));
    expect(vomSonntag, equals(vomMontag));
  });

  test('ueber den Monatswechsel bleibt die Woche zusammen', () {
    final woche = weekOf(DateTime(2026, 10, 1)); // Donnerstag
    expect(woche.first, DateTime(2026, 9, 28));
    expect(woche.last, DateTime(2026, 10, 4));
  });

  test('ohne Speicher ist die Woche leer, aber vollstaendig', () async {
    final status = await readWeekStatus(null, DateTime(2026, 9, 10));

    expect(status.days.length, 7);
    expect(status.total, 0);
    expect(status.played, 0);
    expect(status.days.every((tag) => tag.score == null), isTrue);
  });

  test('jeder Tag hat seinen eigenen Spielcode', () {
    final status = WeekStatus([
      for (final tag in weekOf(DateTime(2026, 9, 10)))
        WeekDay(
          date: tag,
          code: codeForDate(tag),
          score: null,
          isToday: false,
          isFuture: false,
        ),
    ]);
    expect(status.days.map((tag) => tag.code).toSet().length, 7);
    expect(status.days.first.code, 20260907);
    expect(status.days.last.code, 20260913);
  });

  test('gespielte Tage zaehlen zur Wochensumme', () async {
    final store = await speicher();
    await recordDailyResult(store, DateTime(2026, 9, 7), 1200);
    await recordDailyResult(store, DateTime(2026, 9, 8), 800);
    await recordDailyResult(store, DateTime(2026, 9, 10), 3000);

    final status = await readWeekStatus(store, DateTime(2026, 9, 10));

    expect(status.played, 3);
    expect(status.total, 5000);
    expect(status.days[0].score, 1200);
    expect(status.days[2].score, isNull, reason: 'der Mittwoch fehlt');
    expect(status.days[3].score, 3000);
  });

  test('heute und kommende Tage sind auseinanderzuhalten', () async {
    final status = await readWeekStatus(null, DateTime(2026, 9, 10));

    expect(status.days[3].isToday, isTrue, reason: 'Donnerstag');
    expect(status.days[3].isFuture, isFalse);
    expect(status.days[0].isFuture, isFalse, reason: 'Montag ist vorbei');
    expect(status.days[4].isFuture, isTrue, reason: 'Freitag kommt noch');
    expect(status.days[6].isFuture, isTrue);
  });

  test('eine andere Woche zaehlt nicht mit', () async {
    final store = await speicher();
    await recordDailyResult(store, DateTime(2026, 9, 3), 9999); // Vorwoche

    final status = await readWeekStatus(store, DateTime(2026, 9, 10));
    expect(status.total, 0);
    expect(status.played, 0);
  });
}
