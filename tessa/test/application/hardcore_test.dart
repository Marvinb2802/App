import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/shop.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/data/database.dart';
import 'package:tessa/data/store.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/hardcore.dart';
import 'package:tessa/domain/rules/placement.dart';

import '../support/fake_sound.dart';

/// Wartet, bis [pruefung] zutrifft — das Sichern laeuft nebenher.
Future<void> _bis(Future<bool> Function() pruefung) async {
  for (var versuch = 0; versuch < 200; versuch++) {
    if (await pruefung()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  final square = PieceCatalog.byId('square2');

  ProviderContainer container({
    ShopState? shop,
    TessaStore? store,
    GameState? restored,
  }) {
    final c = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => 4242),
        if (shop != null) initialShopProvider.overrideWithValue(shop),
        if (store != null) storeProvider.overrideWithValue(store),
        if (restored != null) restoredGameProvider.overrideWithValue(restored),
      ],
    );
    c.read(gameModeProvider.notifier).set(GameMode.hardcore);
    return c;
  }

  /// Startet eine Hardcore-Runde und gibt den Container zurueck.
  ProviderContainer hardcoreRunde({ShopState? shop, TessaStore? store}) {
    final c = container(shop: shop, store: store);
    c.read(gameControllerProvider.notifier).restart();
    return c;
  }

  /// Legt irgendein Teil irgendwohin. Gibt false zurueck, wenn nichts mehr
  /// passt.
  bool spieleZug(ProviderContainer c) {
    final state = c.read(gameControllerProvider);
    for (var slot = 0; slot < Hand.slotCount; slot++) {
      final piece = state.hand.pieceAt(slot);
      if (piece == null) continue;
      final plaetze = placementsFor(state.board, piece);
      if (plaetze.isEmpty) continue;
      return c.read(gameControllerProvider.notifier)
          .place(slot: slot, x: plaetze.first.x, y: plaetze.first.y);
    }
    return false;
  }

  group('Eine Hardcore-Runde', () {
    test('zieht aus dem harten Satz und hat keine Zurueck-Zuege', () {
      final state = hardcoreRunde().read(gameControllerProvider);
      expect(state.pieces, PieceSet.hardcore);
      expect(state.undosLeft, 0);
      expect(state.canUndo, isFalse);
    });

    test('nimmt keinen Zug zurueck', () {
      final c = hardcoreRunde();
      spieleZug(c);
      final nachDemZug = c.read(gameControllerProvider);

      expect(c.read(gameControllerProvider.notifier).undo(), isFalse);
      expect(c.read(gameControllerProvider).board, equals(nachDemZug.board));
      expect(c.read(gameControllerProvider).score, nachDemZug.score);
    });

    test('gibt keinen Hinweis', () {
      final c = hardcoreRunde();
      expect(c.read(hintProvider.notifier).request(), isFalse);
      expect(c.read(hintProvider).shown, isNull);
    });

    test('laesst nach dem Ende nicht weiterspielen', () {
      final ende = GameState(
        seed: 4242,
        handIndex: 3,
        board: Board.fromRows(List.filled(8, '########')),
        hand: Hand.of([square, square, square]),
        score: 900,
        combo: 1,
        undosLeft: 0,
        isOver: true,
        pieces: PieceSet.hardcore,
      );
      final c = container(
        shop: const ShopState(revives: 3),
        restored: ende,
      );

      expect(c.read(gameControllerProvider.notifier).revive(), isFalse);
      expect(c.read(gameControllerProvider).isOver, isTrue);
      expect(c.read(shopProvider).revives, 3, reason: 'nichts verbraucht');
    });
  });

  group('Gekaufte Hilfe wirkt in Hardcore nicht', () {
    // Der Wächter zu CLAUDE.md: In Hardcore gibt es keine Hilfe — auch keine
    // bezahlte. Sonst waere der Modus mit Sternen aushebelbar.
    test('gekaufte Hinweise bleiben wirkungslos', () {
      final c = hardcoreRunde(shop: const ShopState(stars: 999));
      final hinweise = shopItems.firstWhere((i) => i.kind == ShopKind.hints);

      expect(c.read(shopProvider.notifier).buy(hinweise), isTrue,
          reason: 'kaufen darf man, es hilft nur nichts');
      expect(c.read(hintProvider.notifier).request(), isFalse);
      expect(c.read(hintProvider).shown, isNull);
    });

    test('gekaufte Zurueck-Zuege bleiben wirkungslos', () {
      final c = hardcoreRunde(shop: const ShopState(stars: 999));
      final undos = shopItems.firstWhere((i) => i.kind == ShopKind.undos);

      expect(c.read(shopProvider.notifier).buy(undos), isTrue);
      expect(c.read(gameControllerProvider).undosLeft, 0);

      spieleZug(c);
      expect(c.read(gameControllerProvider.notifier).undo(), isFalse);
    });

    test('allowsHelp nennt genau einen Modus ohne Hilfe', () {
      for (final mode in GameMode.values) {
        expect(allowsHelp(mode), mode != GameMode.hardcore, reason: '$mode');
      }
    });
  });

  group('Geroell im Spielablauf', () {
    test('faellt waehrend der Schonfrist nicht', () {
      final c = hardcoreRunde();
      var gelegt = 0;
      for (var zug = 0; zug < Hardcore.gracePeriod; zug++) {
        final vorher = c.read(gameControllerProvider);
        spieleZug(c);
        final nachher = c.read(gameControllerProvider);
        if (nachher.lastMove!.clearedLines > 0) continue;
        gelegt += nachher.lastMove!.placedCellCount;
        expect(nachher.board.filledCount, vorher.board.filledCount + nachher.lastMove!.placedCellCount,
            reason: 'in den ersten Zuegen faellt nichts dazu');
      }
      expect(gelegt, greaterThan(0));
    });

    test('faellt danach und fuellt das Brett zusaetzlich', () {
      final c = hardcoreRunde();
      var geroell = 0;
      for (var zug = 1; zug <= Hardcore.gracePeriod + 6; zug++) {
        final vorher = c.read(gameControllerProvider);
        if (vorher.isOver) break;
        spieleZug(c);
        final nachher = c.read(gameControllerProvider);
        if (nachher.lastMove!.clearedLines > 0) continue;
        final dazu = nachher.board.filledCount -
            vorher.board.filledCount -
            nachher.lastMove!.placedCellCount;
        geroell += dazu;
      }
      expect(geroell, greaterThan(0),
          reason: 'nach der Schonfrist kommen Steine dazu, die niemand legte');
    });
  });

  group('Was von einer Hardcore-Runde bleibt', () {
    Future<TessaDatabase> openMemory() => TessaDatabase.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );

    test('die laufende Runde wird nicht gesichert', () async {
      final database = await openMemory();
      addTearDown(database.close);
      final c = hardcoreRunde(store: SqfliteStore(database));

      for (var zug = 0; zug < 4; zug++) {
        spieleZug(c);
      }
      // Dem Sichern Zeit geben — es laeuft nebenher.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await database.games.load(), isNull,
          reason: 'eine Hardcore-Runde laeuft in einem Stueck');
    });

    test('das Ergebnis geht in den eigenen Bestwert, nicht in die Bestenliste',
        () async {
      final database = await openMemory();
      addTearDown(database.close);
      final store = SqfliteStore(database);
      final c = hardcoreRunde(store: store);

      // Bis zum Ende spielen — in Hardcore dauert das keine 200 Zuege.
      var zuege = 0;
      while (!c.read(gameControllerProvider).isOver && zuege < 200) {
        spieleZug(c);
        zuege += 1;
      }
      final ende = c.read(gameControllerProvider);
      expect(ende.isOver, isTrue, reason: 'die Runde endet von allein');
      expect(ende.score, greaterThan(0));

      await _bis(() async =>
          await store.readSetting('hardcore.best') == '${ende.score}');

      expect(await store.readSetting('hardcore.best'), '${ende.score}');
      expect(await store.topScores(), isEmpty,
          reason: 'Hardcore steht nicht in der gewoehnlichen Bestenliste');
      expect(await store.loadGame(), isNull,
          reason: 'nach dem Ende bleibt keine offene Partie');
      expect(c.read(shopProvider).stars, ende.score ~/ 250,
          reason: 'Sterne gibt es wie sonst auch');
    });

    test('ein schlechteres Ergebnis ueberschreibt den Bestwert nicht',
        () async {
      final database = await openMemory();
      addTearDown(database.close);
      final store = SqfliteStore(database);
      await store.writeSetting('hardcore.best', '99999');

      final c = hardcoreRunde(store: store);
      var zuege = 0;
      while (!c.read(gameControllerProvider).isOver && zuege < 200) {
        spieleZug(c);
        zuege += 1;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await store.readSetting('hardcore.best'), '99999');
    });
  });
}
