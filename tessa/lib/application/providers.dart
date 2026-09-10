import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../domain/model/game_state.dart';
import '../domain/rules/placement.dart';
import 'drag_controller.dart';
import 'game_controller.dart';

/// Liefert den Seed fuer eine neue Runde.
typedef SeedSource = int Function();

/// Woher der Seed einer Runde kommt.
///
/// Nur die *Wahl* des Seeds ist zufaellig — die Steinsequenz selbst leitet
/// sich danach ausschliesslich aus ihm ab (siehe CLAUDE.md). Tests ersetzen
/// diese Quelle durch einen festen Wert.
final seedSourceProvider = Provider<SeedSource>((ref) {
  final random = Random();
  return () => random.nextInt(0x100000000);
});

/// Die geoeffnete Datenbank — oder null, wenn keine da ist.
///
/// Tessa laeuft auch ohne: dann wird nur nichts gesichert. main() ersetzt
/// diesen Wert beim Start, Tests lassen ihn null.
final databaseProvider = Provider<TessaDatabase?>((ref) => null);

/// Eine beim Start geladene, noch offene Partie.
final restoredGameProvider = Provider<GameState?>((ref) => null);

/// Der Spielstand der laufenden Runde.
final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Der laufende Zieh-Vorgang.
final dragControllerProvider =
    NotifierProvider<DragController, DragState>(DragController.new);

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
