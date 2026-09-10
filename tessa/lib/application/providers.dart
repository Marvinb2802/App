import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/score_dao.dart';
import '../data/store.dart';
import '../domain/model/game_state.dart';
import '../domain/rules/placement.dart';
import 'daily.dart';
import 'drag_controller.dart';
import 'game_controller.dart';
import 'hint_controller.dart';
import 'round_log.dart';

/// Liefert den Spielcode fuer eine neue Runde.
typedef SeedSource = int Function();

/// Woher der Spielcode einer Runde kommt.
///
/// Nur die *Wahl* des Codes ist zufaellig — die Steinfolge leitet sich danach
/// ausschliesslich aus ihm ab (siehe CLAUDE.md). Tests ersetzen diese Quelle
/// durch einen festen Wert.
final seedSourceProvider = Provider<SeedSource>((ref) {
  final random = Random();
  return () => random.nextInt(0x100000000);
});

/// Der Speicher — oder null, wenn keiner zur Verfuegung steht.
///
/// Tessa laeuft auch ohne: dann wird nur nichts gesichert. main() ersetzt
/// diesen Wert beim Start, Tests lassen ihn null.
final storeProvider = Provider<TessaStore?>((ref) => null);

/// Eine beim Start geladene, noch offene Partie.
final restoredGameProvider = Provider<GameState?>((ref) => null);

/// Das heutige Datum. Als Provider, damit Tests einen festen Tag setzen koennen.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Der Spielcode des heutigen Tagesraetsels.
final dailyCodeProvider =
    Provider<int>((ref) => codeForDate(ref.watch(todayProvider)));

/// Ob das Tagesraetsel heute schon gespielt wurde, und die laufende Serie.
final dailyStatusProvider = FutureProvider<DailyStatus>((ref) =>
    readDailyStatus(ref.watch(storeProvider), ref.watch(todayProvider)));

/// Der Spielstand der laufenden Runde.
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Der laufende Zieh-Vorgang.
final dragControllerProvider =
    NotifierProvider<DragController, DragState>(DragController.new);

/// Hinweise: wie viele noch uebrig sind und welcher Zug gerade gezeigt wird.
final hintProvider =
    NotifierProvider<HintController, HintState>(HintController.new);

/// Der Verlauf der laufenden Runde — fuer Analyse und Tagesziel.
final roundLogProvider =
    NotifierProvider<RoundLogController, RoundLog>(RoundLogController.new);

/// Die besten Runden. Ohne Speicher bleibt die Liste leer.
final topScoresProvider = FutureProvider<List<ScoreEntry>>((ref) async {
  final store = ref.watch(storeProvider);
  if (store == null) return const [];
  return store.topScores();
});

/// Die hoechste je erreichte Punktzahl.
final bestScoreProvider = FutureProvider<int>((ref) async {
  final store = ref.watch(storeProvider);
  if (store == null) return 0;
  return store.bestScore();
});

/// Der beste Wert zu einem bestimmten Spielcode — die Messlatte beim
/// Nachspielen und beim Tuefteln.
final bestForCodeProvider =
    FutureProvider.family<int, int>((ref, seed) async {
  final store = ref.watch(storeProvider);
  if (store == null) return 0;
  return store.bestForSeed(seed);
});

/// Gespielte Runden und deren Punktsumme — Grundlage der Statistik.
final totalsProvider = FutureProvider<({int rounds, int points})>((ref) async {
  final store = ref.watch(storeProvider);
  if (store == null) return (rounds: 0, points: 0);
  return store.totals();
});

/// Ob das Geraet beim Legen kurz vibriert. main() setzt den gespeicherten Wert.
final initialHapticsProvider = Provider<bool>((ref) => true);

class HapticsController extends Notifier<bool> {
  @override
  bool build() => ref.read(initialHapticsProvider);

  Future<void> toggle() async {
    state = !state;
    await ref.read(storeProvider)?.writeSetting('haptics', state ? '1' : '0');
  }
}

final hapticsProvider =
    NotifierProvider<HapticsController, bool>(HapticsController.new);

/// Was waehrend des Ziehens auf dem Brett angezeigt wird.
final dragPreviewProvider = Provider<DragPreview>((ref) {
  final drag = ref.watch(dragControllerProvider);
  final game = ref.watch(gameControllerProvider);

  final slot = drag.slot;
  final anchor = drag.anchor;
  if (slot == null) return DragPreview.none;

  final piece = game.hand.pieceAt(slot);
  if (piece == null || anchor == null) {
    return DragPreview(slot: slot, cells: const [], isValid: false);
  }
  return DragPreview(
    slot: slot,
    cells: cellsAt(piece, anchor.x, anchor.y).toList(),
    isValid: canPlace(game.board, piece, anchor.x, anchor.y),
  );
});
