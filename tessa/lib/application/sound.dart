import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Die Klaenge des Spiels.
class Sounds {
  Sounds._();

  static const String place = 'sounds/place.wav';
  static const String gameOver = 'sounds/gameover.wav';

  /// Beim Aufloesen steigt die Tonhoehe mit der Combo — man hoert, dass es
  /// gerade gut laeuft.
  static String clear(int combo) => 'sounds/clear${combo.clamp(1, 9)}.wav';
}

/// Wohin die Toene gehen. In Tests wird das durch eine Attrappe ersetzt,
/// damit sich pruefen laesst, *was* gespielt wuerde.
abstract class SoundOutput {
  Future<void> play(String asset);
  Future<void> dispose();
}

/// Spielt die Klaenge wirklich ab.
class AudioPlayersOutput implements SoundOutput {
  final Map<String, AudioPlayer> _players = {};

  @override
  Future<void> play(String asset) async {
    final player = _players.putIfAbsent(
      asset,
      () => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
    );
    // Neu anfangen, falls der Klang noch laeuft: schnelle Zuege sollen sich
    // nicht gegenseitig verschlucken.
    await player.stop();
    await player.play(AssetSource(asset));
  }

  @override
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

final soundOutputProvider = Provider<SoundOutput>((ref) {
  final output = AudioPlayersOutput();
  ref.onDispose(output.dispose);
  return output;
});

/// Ob Toene gespielt werden. main() setzt den gespeicherten Wert.
final initialSoundProvider = Provider<bool>((ref) => true);

class SoundController extends Notifier<bool> {
  @override
  bool build() => ref.read(initialSoundProvider);

  Future<void> toggle() async {
    state = !state;
    await ref.read(storeProvider)?.writeSetting('sound', state ? '1' : '0');
  }

  /// Spielt einen Klang, sofern Toene an sind. Fehler beim Abspielen duerfen
  /// das Spiel nicht stoeren.
  void play(String asset) {
    if (!state) return;
    unawaited(
      ref.read(soundOutputProvider).play(asset).catchError((Object _) {}),
    );
  }
}

final soundProvider =
    NotifierProvider<SoundController, bool>(SoundController.new);
