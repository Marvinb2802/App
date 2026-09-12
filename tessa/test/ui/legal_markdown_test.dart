import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/ui/legal/markdown.dart';

void main() {
  test('erkennt Titel und Abschnitt', () {
    final bloecke = parseLegal('# Impressum\n\n## Anbieter\n\nText.');
    expect(bloecke.map((b) => b.art), [
      BlockArt.titel,
      BlockArt.abschnitt,
      BlockArt.absatz,
    ]);
    expect(bloecke.first.text, 'Impressum');
    expect(bloecke[1].text, 'Anbieter');
  });

  test('zieht die Zeilen eines Absatzes zusammen', () {
    // Der Quelltext ist auf knapp 80 Zeichen umgebrochen — diese Umbrueche
    // duerfen nicht in der Anzeige landen.
    final block = parseLegal(
      'Ein langer Satz, der im\nQuelltext umgebrochen '
      'ist.',
    ).single;
    expect(block.art, BlockArt.absatz);
    expect(block.zeilen, [
      'Ein langer Satz, der im Quelltext umgebrochen ist.',
    ]);
  });

  test('haelt Umbrueche, wo eine Zeile mit Rueckstrich endet', () {
    final block = parseLegal('Marvin B\\\nMusterweg 1\\\n12345 Musterstadt')
        .single;
    expect(block.zeilen, ['Marvin B', 'Musterweg 1', '12345 Musterstadt']);
  });

  test('liest Aufzaehlungen samt eingerueckter Folgezeilen', () {
    final block = parseLegal(
      '- Farbsets — dauerhaft\n'
      '- Hinweise, die sich mit\n  der Nutzung aufbrauchen',
    ).single;
    expect(block.art, BlockArt.punkte);
    expect(block.zeilen, [
      'Farbsets — dauerhaft',
      'Hinweise, die sich mit der Nutzung aufbrauchen',
    ]);
  });

  test('liest nummerierte Schritte', () {
    final block = parseLegal('1. erstens\n2. zweitens').single;
    expect(block.art, BlockArt.schritte);
    expect(block.zeilen, ['erstens', 'zweitens']);
  });

  test('entfernt Sternchen fuer Fettschrift', () {
    expect(
      parseLegal('**Farbsets** — dauerhaft').single.text,
      'Farbsets — dauerhaft',
    );
  });

  test('ueberspringt leere Bloecke', () {
    expect(parseLegal('\n\n\nText\n\n\n\n').single.text, 'Text');
  });
}
