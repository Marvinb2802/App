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
  });

  static const DailyStatus unknown =
      DailyStatus(playedToday: false, streak: 0, lastScore: null);

  final bool playedToday;

  /// Wie viele Tage in Folge das Raetsel gespielt wurde.
  final int streak;

  /// Die Punktzahl des zuletzt gespielten Tagesraetsels.
  final int? lastScore;
}

const String _lastDateKey = 'daily.lastDate';
const String _streakKey = 'daily.streak';
const String _lastScoreKey = 'daily.lastScore';

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
  );
}

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
}
