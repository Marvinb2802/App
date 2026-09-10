import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'application/shop.dart';
import 'application/sound.dart';
import 'data/database.dart';
import 'data/prefs_store.dart';
import 'data/purchases.dart';
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
  var sound = true;
  var shop = const ShopState();
  if (store != null) {
    try {
      restored = await store.loadGame();
      haptics = await store.readSetting('haptics') != '0';
      sound = await store.readSetting('sound') != '0';
      shop = ShopState.fromJson(await store.readSetting('shop'));
    } catch (_) {
      restored = null;
    }
  }

  // Kaeufe gibt es nur in der echten App: im Browser fehlt das Bezahlsystem
  // der Plattform.
  Purchases purchases = const UnavailablePurchases();
  if (!kIsWeb) {
    try {
      final store = StorePurchases();
      if (await store.available()) purchases = store;
    } catch (_) {
      purchases = const UnavailablePurchases();
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        purchasesProvider.overrideWithValue(purchases),
        storeProvider.overrideWithValue(store),
        restoredGameProvider.overrideWithValue(restored),
        initialHapticsProvider.overrideWithValue(haptics),
        initialSoundProvider.overrideWithValue(sound),
        initialShopProvider.overrideWithValue(shop),
      ],
      child: const TessaApp(),
    ),
  );
}
