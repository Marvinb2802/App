import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'data/database.dart';
import 'domain/model/game_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tessa spielt auch ohne Datenbank. Laesst sie sich nicht oeffnen, geht die
  // Runde trotzdem los — nur ohne Sichern.
  TessaDatabase? database;
  GameState? restored;
  try {
    database = await TessaDatabase.open();
    restored = await database.games.load();
  } catch (_) {
    database = null;
    restored = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        restoredGameProvider.overrideWithValue(restored),
      ],
      child: const TessaApp(),
    ),
  );
}
