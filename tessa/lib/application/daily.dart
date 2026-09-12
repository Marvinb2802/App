import '../data/store.dart';

/// Der Spielcode des Tages, gebildet aus dem Datum: 10.09.2026 wird 20260910.
///
/// Damit spielen alle am selben Tag dieselbe Runde — und weil der Code allein
/// aus dem Datum kommt, laesst er sich nachrechnen und nachspielen.
int codeForDate(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Stand des Tagesraetsels.
class DailyStatus {
  const DailyStatus({
    required this.playedToday,
    required this.streak,
    required this.lastScore,
    required this.goalReachedToday,
  });

  static const DailyStatus unknown = DailyStatus(
    playedToday: false,
    streak: 0,
    lastScore: null,
    goalReachedToday: false,
  );

  final bool playedToday;

  /// Wie viele Tage in Folge das Raetsel gespielt wurde.
  final int streak;

  /// Die Punktzahl des zuletzt gespielten Tagesraetsels.
  final int? lastScore;

  /// Ob das Ziel des Tages heute schon geschafft wurde.
  final bool goalReachedToday;
}

const String _lastDateKey = 'daily.lastDate';
const String _streakKey = 'daily.streak';
const String _lastScoreKey = 'daily.lastScore';
const String _goalDateKey = 'daily.goalDate';
String _scoreKeyFor(DateTime day) => 'daily.score.${_dayKey(day)}';

Future<DailyStatus> readDailyStatus(TessaStore? store, DateTime today) async {
  if (store == null) return DailyStatus.unknown;
  final lastDate = await store.readSetting(_lastDateKey);
  final streak = int.tryParse(await store.readSetting(_streakKey) ?? '') ?? 0;
  final lastScore = int.tryParse(await store.readSetting(_lastScoreKey) ?? '');
  final gestern = DateTime(today.year, today.month, today.day - 1);

  // Eine Serie, die gestern endete, laeuft noch; eine aeltere ist gerissen.
  final laeuftNoch =
      lastDate == _dayKey(today) || lastDate == _dayKey(gestern);
  return DailyStatus(
    playedToday: lastDate == _dayKey(today),
    streak: laeuftNoch ? streak : 0,
    lastScore: lastScore,
    goalReachedToday: await store.readSetting(_goalDateKey) == _dayKey(today),
  );
}

/// Haelt fest, dass das Ziel des Tages geschafft wurde.
Future<void> recordDailyGoal(TessaStore store, DateTime today) =>
    store.writeSetting(_goalDateKey, _dayKey(today));

/// Haelt fest, dass das Tagesraetsel gespielt wurde, und fuehrt die Serie fort.
Future<void> recordDailyResult(
  TessaStore store,
  DateTime today,
  int score,
) async {
  final lastDate = await store.readSetting(_lastDateKey);
  if (lastDate == _dayKey(today)) return; // heute schon gezaehlt

  final gestern = DateTime(today.year, today.month, today.day - 1);
  final bisher = int.tryParse(await store.readSetting(_streakKey) ?? '') ?? 0;
  final streak = lastDate == _dayKey(gestern) ? bisher + 1 : 1;

  await store.writeSetting(_lastDateKey, _dayKey(today));
  await store.writeSetting(_streakKey, '$streak');
  await store.writeSetting(_lastScoreKey, '$score');
  // Fuer das Wochenraetsel wird jeder Tag einzeln festgehalten.
  await store.writeSetting(_scoreKeyFor(today), '$score');
}

/// Die sieben Tage der Woche, in der [date] liegt — Montag bis Sonntag.
List<DateTime> weekOf(DateTime date) {
  final montag = DateTime(date.year, date.month, date.day - (date.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      DateTime(montag.year, montag.month, montag.day + i),
  ];
}

/// Ein Tag im Wochenraetsel.
class WeekDay {
  const WeekDay({
    required this.date,
    required this.code,
    required this.score,
    required this.isToday,
    required this.isFuture,
  });

  final DateTime date;
  final int code;

  /// Die erreichte Punktzahl, oder null, wenn der Tag noch offen ist.
  final int? score;

  final bool isToday;
  final bool isFuture;
}

/// Die laufende Woche mit allen sieben Raetseln.
class WeekStatus {
  const WeekStatus(this.days);

  static const WeekStatus unknown = WeekStatus([]);

  final List<WeekDay> days;

  /// Alle Punkte der Woche zusammen.
  int get total =>
      days.fold(0, (summe, tag) => summe + (tag.score ?? 0));

  /// Wie viele Tage schon gespielt sind.
  int get played => days.where((tag) => tag.score != null).length;

  bool get isEmpty => days.isEmpty;
}

Future<WeekStatus> readWeekStatus(TessaStore? store, DateTime today) async {
  final heute = DateTime(today.year, today.month, today.day);
  final tage = <WeekDay>[];

  for (final tag in weekOf(heute)) {
    final gespeichert =
        store == null ? null : await store.readSetting(_scoreKeyFor(tag));
    tage.add(WeekDay(
      date: tag,
      code: codeForDate(tag),
      score: int.tryParse(gespeichert ?? ''),
      isToday: tag == heute,
      isFuture: tag.isAfter(heute),
    ));
  }
  return WeekStatus(tage);
}
