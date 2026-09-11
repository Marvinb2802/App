import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/ui/legal/legal_repository.dart';

/// Ein Bündel, das die Texte aus dem Arbeitsspeicher liefert — damit die Tests
/// vom Inhalt der echten Vorlagen unabhängig sind.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.dateien);

  final Map<String, String> dateien;

  @override
  Future<ByteData> load(String key) async {
    final inhalt = dateien[key];
    if (inhalt == null) throw StateError('Kein Anhang: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(inhalt)));
  }
}

Betreiber _vollstaendig({String umsatzsteuerId = ''}) => Betreiber(
  name: 'Marvin B',
  strasse: 'Musterweg 1',
  ort: '12345 Musterstadt',
  land: 'Deutschland',
  email: 'post@example.de',
  umsatzsteuerId: umsatzsteuerId,
  stand: 'September 2026',
);

void main() {
  group('Betreiber', () {
    test('gilt als ausgefuellt, wenn die Pflichtangaben stehen', () {
      expect(_vollstaendig().istAusgefuellt, isTrue);
    });

    test('gilt als nicht ausgefuellt, solange ein Platzhalter steht', () {
      final roh = Betreiber.fromJson(<String, dynamic>{
        'name': '[DEIN VOLLER NAME]',
        'strasse': 'Musterweg 1',
        'ort': '12345 Musterstadt',
        'land': 'Deutschland',
        'email': 'post@example.de',
        'umsatzsteuerId': '',
        'stand': 'September 2026',
      });
      expect(roh.istAusgefuellt, isFalse);
    });

    test('gilt als nicht ausgefuellt, wenn eine Pflichtangabe leer ist', () {
      final ohneOrt = Betreiber.fromJson(<String, dynamic>{
        'name': 'Marvin B',
        'strasse': 'Musterweg 1',
        'ort': '   ',
        'email': 'post@example.de',
      });
      expect(ohneOrt.istAusgefuellt, isFalse);
    });

    test('nennt ohne Nummer die Kleinunternehmerregelung', () {
      expect(_vollstaendig().umsatzsteuerHinweis, contains('§ 19 UStG'));
    });

    test('nennt mit Nummer die Umsatzsteuer-Identifikationsnummer', () {
      final hinweis = _vollstaendig(umsatzsteuerId: 'DE123456789')
          .umsatzsteuerHinweis;
      expect(hinweis, contains('DE123456789'));
      expect(hinweis, isNot(contains('§ 19')));
    });
  });

  group('fuelleEin', () {
    test('setzt alle Angaben ein', () {
      final text = fuelleEin(
        '{{name}} — {{strasse}}, {{ort}}, {{land}} ({{email}}), '
        'Stand {{stand}}. {{umsatzsteuerHinweis}}',
        _vollstaendig(),
      );
      expect(text, contains('Marvin B'));
      expect(text, contains('12345 Musterstadt'));
      expect(text, contains('post@example.de'));
      expect(text, contains('September 2026'));
      expect(text, contains('§ 19 UStG'));
    });

    test('laesst keinen Platzhalter stehen', () {
      final text = fuelleEin(
        'a {{name}} b {{strasse}} c {{ort}} d {{land}} e {{email}} '
        'f {{stand}} g {{umsatzsteuerHinweis}}',
        _vollstaendig(),
      );
      expect(text, isNot(contains('{{')));
    });
  });

  group('LegalRepository', () {
    test('liest die Angaben und setzt sie in einen Text ein', () async {
      final repo = LegalRepository(
        _FakeBundle({
          'assets/legal/betreiber.json': jsonEncode({
            'name': 'Marvin B',
            'strasse': 'Musterweg 1',
            'ort': '12345 Musterstadt',
            'land': 'Deutschland',
            'email': 'post@example.de',
            'umsatzsteuerId': '',
            'stand': 'September 2026',
          }),
          'assets/legal/impressum.md': '# Impressum\n\n{{name}}\n{{ort}}',
        }),
      );

      final betreiber = await repo.betreiber();
      expect(betreiber.name, 'Marvin B');
      expect(betreiber.istAusgefuellt, isTrue);

      final text = await repo.text(LegalDoc.impressum);
      expect(text, contains('Marvin B'));
      expect(text, isNot(contains('{{')));
    });
  });
}
