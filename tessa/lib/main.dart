import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/database.dart';
import 'data/prefs_store.dart';
import 'data/store.dart';
import 'domain/model/game_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auf dem Geraet sqflite; wo es das nicht gibt (Browser), der Speicher des
  // Systems. Klappt beides nicht, laeuft Tessa ohne Sichern weiter.
  TessaStore? store;
  try {
    store = SqfliteStore(await TessaDatabase.open());
  } catch (_) {
    try {
      store = await PrefsStore.open();
    } catch (_) {
      store = null;
    }
  }

  GameState? restored;
  var haptics = true;
  if (store != null) {
    try {
      restored = await store.loadGame();
      haptics = await store.readSetting('haptics') != '0';
    } catch (_) {
      restored = null;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        restoredGameProvider.overrideWithValue(restored),
        initialHapticsProvider.overrideWithValue(haptics),
      ],
      child: const TessaApp(),
    ),
  );
}
