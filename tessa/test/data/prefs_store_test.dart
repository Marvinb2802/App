import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tessa/data/prefs_store.dart';
import 'package:tessa/domain/rules/move.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> offen() async {
    SharedPreferences.setMockInitialValues({});
    return PrefsStore.open();
  }

  test('sichert eine Partie und holt sie zurueck', () async {
    final store = await offen();
    var state = startGame(4711);
    state = applyMove(state, slot: 0, x: 0, y: 0);

    await store.saveGame(state);
    final geladen = await store.loadGame();

    expect(geladen, isNotNull);
    expect(geladen!.seed, 4711);
    expect(geladen.board, equals(state.board));
    expect(geladen.hand, equals(state.hand));
    expect(geladen.score, state.score);
  });

  test('ohne gesicherte Partie kommt null', () async {
    expect(await (await offen()).loadGame(), isNull);
  });

  test('ein beschaedigter Eintrag fuehrt nicht zum Absturz', () async {
    SharedPreferences.setMockInitialValues({'tessa.game': 'kaputt'});
    final store = await PrefsStore.open();
    expect(await store.loadGame(), isNull);
  });

  test('fuehrt die Bestenliste sortiert', () async {
    final store = await offen();
    await store.addScore(score: 120, seed: 1);
    await store.addScore(score: 4300, seed: 2);
    await store.addScore(score: 900, seed: 3);

    final top = await store.topScores();
    expect(top.map((e) => e.score), [4300, 900, 120]);
    expect(top.first.seed, 2);
    expect(await store.bestScore(), 4300);
  });

  test('zaehlt Runden und Punkte fuer die Statistik', () async {
    final store = await offen();
    await store.addScore(score: 100, seed: 1);
    await store.addScore(score: 300, seed: 2);

    final totals = await store.totals();
    expect(totals.rounds, 2);
    expect(totals.points, 400);
  });

  test('merkt sich Einstellungen', () async {
    final store = await offen();
    expect(await store.readSetting('haptics'), isNull);
    await store.writeSetting('haptics', '0');
    expect(await store.readSetting('haptics'), '0');
  });
}
