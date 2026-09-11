import 'dart:convert';
import 'dart:io';

import 'package:tessa/ui/legal/legal_repository.dart';

/// Liest die ausgelieferten Vorlagen direkt von der Platte.
///
/// `rootBundle` ist dafür im Widget-Test unbrauchbar: das Laden eines Anhangs
/// läuft über echte Ein-/Ausgabe und kommt in der künstlichen Zeit eines
/// Widget-Tests nie zurück — der Test bliebe hängen. Von der Platte gelesen
/// sind es dieselben Dateien, nur ohne Wartezeit.
class VorlagenRepo implements LegalRepository {
  VorlagenRepo({this.angaben});

  /// Wenn gesetzt, werden diese Angaben eingesetzt statt derer aus
  /// `assets/legal/betreiber.json`.
  final Betreiber? angaben;

  static String lies(String pfad) => File(pfad).readAsStringSync();

  @override
  Future<Betreiber> betreiber() async =>
      angaben ??
      Betreiber.fromJson(
        jsonDecode(lies('assets/legal/betreiber.json')) as Map<String, dynamic>,
      );

  @override
  Future<String> text(LegalDoc doc) async =>
      fuelleEin(lies(doc.datei), await betreiber());
}

/// Ein Betreiber, bei dem alles eingetragen ist.
const ausgefuellterBetreiber = Betreiber(
  name: 'Marvin B',
  strasse: 'Musterweg 1',
  ort: '12345 Musterstadt',
  land: 'Deutschland',
  email: 'post@example.de',
  umsatzsteuerId: '',
  stand: 'September 2026',
);
