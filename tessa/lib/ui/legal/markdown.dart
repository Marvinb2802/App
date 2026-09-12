/// Ein sehr kleiner Markdown-Leser — gerade genug für die vier Rechtstexte.
///
/// Ein ganzes Markdown-Paket wäre dafür zu viel Gepäck. Dieselben Regeln
/// stehen ein zweites Mal in `tool/make_web.py`, das aus denselben Dateien die
/// öffentlichen Webseiten baut; die Tests in `legal_markdown_test.dart` und
/// `test/tool/` halten beide Fassungen zusammen.
library;

/// Was für ein Abschnitt ein Block ist.
enum BlockArt {
  /// `# Überschrift` — einmal ganz oben.
  titel,

  /// `## Überschrift`
  abschnitt,

  /// Fließtext. `zeilen` enthält je einen Eintrag pro gewolltem Umbruch.
  absatz,

  /// `- Punkt`
  punkte,

  /// `1. Schritt`
  schritte,
}

class LegalBlock {
  const LegalBlock(this.art, this.zeilen);

  final BlockArt art;

  /// Bei [BlockArt.absatz] die sichtbaren Zeilen, bei Listen die Einträge,
  /// bei Überschriften genau eine.
  final List<String> zeilen;

  String get text => zeilen.join('\n');
}

final _punkt = RegExp(r'^[-*]\s+');
final _schritt = RegExp(r'^\d+\.\s+');

/// Zerlegt einen Rechtstext in Blöcke.
///
/// Absätze im Quelltext sind auf knapp 80 Zeichen umgebrochen — diese Umbrüche
/// gehören nicht in die Anzeige, sonst steht der Text auf dem Telefon zerhackt
/// da. Zeilen werden deshalb zusammengezogen; ein Umbruch bleibt nur, wo eine
/// Zeile mit einem Rückstrich endet (wie in Markdown üblich). So behalten
/// Anschriften ihre Form.
List<LegalBlock> parseLegal(String quelle) {
  final bloecke = <LegalBlock>[];

  for (final roh in quelle.replaceAll('\r\n', '\n').split('\n\n')) {
    final zeilen = roh
        .split('\n')
        .map((z) => z.trimRight())
        .where((z) => z.trim().isNotEmpty)
        .toList();
    if (zeilen.isEmpty) continue;

    final erste = zeilen.first.trimLeft();

    if (erste.startsWith('## ')) {
      bloecke.add(LegalBlock(BlockArt.abschnitt, [_klar(erste.substring(3))]));
    } else if (erste.startsWith('# ')) {
      bloecke.add(LegalBlock(BlockArt.titel, [_klar(erste.substring(2))]));
    } else if (_punkt.hasMatch(erste)) {
      bloecke.add(LegalBlock(BlockArt.punkte, _eintraege(zeilen, _punkt)));
    } else if (_schritt.hasMatch(erste)) {
      bloecke.add(LegalBlock(BlockArt.schritte, _eintraege(zeilen, _schritt)));
    } else {
      bloecke.add(LegalBlock(BlockArt.absatz, _absatzZeilen(zeilen)));
    }
  }
  return bloecke;
}

/// Listeneinträge; eingerückte Folgezeilen gehören zum Eintrag davor.
List<String> _eintraege(List<String> zeilen, RegExp marke) {
  final eintraege = <String>[];
  for (final zeile in zeilen) {
    final ohneRand = zeile.trimLeft();
    if (marke.hasMatch(ohneRand)) {
      eintraege.add(_klar(ohneRand.replaceFirst(marke, '')));
    } else if (eintraege.isNotEmpty) {
      eintraege[eintraege.length - 1] = '${eintraege.last} ${_klar(ohneRand)}'
          .trim();
    } else {
      eintraege.add(_klar(ohneRand));
    }
  }
  return eintraege;
}

/// Zieht die Zeilen eines Absatzes zusammen; ein Rückstrich am Zeilenende
/// erzwingt einen Umbruch.
List<String> _absatzZeilen(List<String> zeilen) {
  final ergebnis = <String>[];
  var laufend = '';

  for (final zeile in zeilen) {
    final hart = zeile.endsWith(r'\');
    final stueck = _klar(hart ? zeile.substring(0, zeile.length - 1) : zeile);
    laufend = laufend.isEmpty ? stueck : '$laufend $stueck';
    if (hart) {
      ergebnis.add(laufend);
      laufend = '';
    }
  }
  if (laufend.isNotEmpty) ergebnis.add(laufend);
  return ergebnis;
}

/// Fettschrift wird in der App nicht gesetzt — die Sternchen müssen weg.
String _klar(String text) => text.replaceAll('**', '').trim();
