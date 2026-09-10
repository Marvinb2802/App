import 'package:tessa/application/sound.dart';

/// Schreibt mit, was gespielt worden waere, statt etwas abzuspielen.
///
/// In Tests gibt es keine Tonausgabe — und so laesst sich ausserdem pruefen,
/// welcher Klang zu welchem Zug gehoert.
class RecordingOutput implements SoundOutput {
  final List<String> played = [];

  /// Wie oft die Klaenge vorbereitet wurden.
  int unlocks = 0;

  @override
  Future<void> play(String asset) async => played.add(asset);

  @override
  Future<void> unlock() async => unlocks += 1;

  @override
  Future<void> dispose() async {}
}
