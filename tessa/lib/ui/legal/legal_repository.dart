import 'dart:convert';

import 'package:flutter/services.dart';

/// Die vier Rechtstexte, wie sie in der App und als Webseite erscheinen.
enum LegalDoc { impressum, datenschutz, agb, widerruf }

extension LegalDocInfo on LegalDoc {
  String get titel => switch (this) {
    LegalDoc.impressum => 'Impressum',
    LegalDoc.datenschutz => 'Datenschutz',
    LegalDoc.agb => 'AGB',
    LegalDoc.widerruf => 'Widerruf',
  };

  String get beschreibung => switch (this) {
    LegalDoc.impressum => 'Wer die App anbietet',
    LegalDoc.datenschutz => 'Was gespeichert wird — und was nicht',
    LegalDoc.agb => 'Bedingungen für Nutzung und Käufe',
    LegalDoc.widerruf => 'Dein Widerrufsrecht bei Käufen',
  };

  String get datei => switch (this) {
    LegalDoc.impressum => 'assets/legal/impressum.md',
    LegalDoc.datenschutz => 'assets/legal/datenschutz.md',
    LegalDoc.agb => 'assets/legal/agb.md',
    LegalDoc.widerruf => 'assets/legal/widerruf.md',
  };
}

/// Die Angaben des Anbieters. Eine Quelle für App und Webseite:
/// `assets/legal/betreiber.json`.
class Betreiber {
  const Betreiber({
    required this.name,
    required this.strasse,
    required this.ort,
    required this.land,
    required this.email,
    required this.umsatzsteuerId,
    required this.stand,
  });

  final String name;
  final String strasse;
  final String ort;
  final String land;
  final String email;
  final String umsatzsteuerId;
  final String stand;

  factory Betreiber.fromJson(Map<String, dynamic> daten) => Betreiber(
    name: daten['name'] as String? ?? '',
    strasse: daten['strasse'] as String? ?? '',
    ort: daten['ort'] as String? ?? '',
    land: daten['land'] as String? ?? '',
    email: daten['email'] as String? ?? '',
    umsatzsteuerId: daten['umsatzsteuerId'] as String? ?? '',
    stand: daten['stand'] as String? ?? '',
  );

  /// Solange irgendwo noch eine eckige Klammer steht, ist die Vorlage nicht
  /// ausgefüllt — dann darf die App nicht veröffentlicht werden.
  bool get istAusgefuellt => ![
    name,
    strasse,
    ort,
    email,
  ].any((wert) => wert.trim().isEmpty || wert.contains('['));

  /// Der Satz zur Umsatzsteuer richtet sich danach, ob eine Nummer vorliegt.
  String get umsatzsteuerHinweis => umsatzsteuerId.trim().isEmpty
      ? 'Kleinunternehmer im Sinne von § 19 UStG. Es wird keine '
            'Umsatzsteuer ausgewiesen.'
      : 'Umsatzsteuer-Identifikationsnummer gemäß § 27a UStG: '
            '$umsatzsteuerId';

  Map<String, String> get platzhalter => {
    'name': name,
    'strasse': strasse,
    'ort': ort,
    'land': land,
    'email': email,
    'stand': stand,
    'umsatzsteuerHinweis': umsatzsteuerHinweis,
  };
}

/// Setzt die Angaben des Anbieters in einen Text ein.
String fuelleEin(String text, Betreiber betreiber) {
  var ergebnis = text;
  betreiber.platzhalter.forEach((schluessel, wert) {
    ergebnis = ergebnis.replaceAll('{{$schluessel}}', wert);
  });
  return ergebnis;
}

/// Lädt die Texte aus den Anhängen der App.
class LegalRepository {
  const LegalRepository(this._bundle);

  final AssetBundle _bundle;

  Future<Betreiber> betreiber() async {
    final roh = await _bundle.loadString('assets/legal/betreiber.json');
    return Betreiber.fromJson(jsonDecode(roh) as Map<String, dynamic>);
  }

  Future<String> text(LegalDoc doc) async {
    final roh = await _bundle.loadString(doc.datei);
    return fuelleEin(roh, await betreiber());
  }
}
