"""Macht aus dem Flutter-Web-Build die auslieferbare Fassung unter docs/.

Drei Dinge, die der Build allein nicht erledigt:

1. CanvasKit ausduennen. Der Build legt jede Renderer-Variante ab (37 MB),
   gebraucht wird bei "renderer: canvaskit" nur canvaskit selbst und die
   Chromium-Fassung.
2. Die Rechtstexte als Webseiten ablegen (docs/legal/). Die Stores verlangen
   eine oeffentlich erreichbare Datenschutzerklaerung — und zwar als Adresse,
   nicht als Bildschirmfoto. Quelle sind dieselben Dateien, die auch die App
   anzeigt: assets/legal/.
3. Einen Service Worker erzeugen. Flutters mitgelieferter meldet sich seit
   Version 3.x selbst ab und speichert nichts zwischen — ohne eigenen gibt es
   kein Offline-Spielen.
4. .nojekyll setzen, damit GitHub Pages die Dateien unveraendert ausliefert.

Vorher bauen:

    flutter build web --release --base-href /App/ --no-web-resources-cdn

Dann:

    python3 tool/make_web.py
"""

import hashlib
import html
import json
import os
import re
import shutil

QUELLE = 'build/web'
ZIEL = '../docs'
RECHT_QUELLE = 'assets/legal'
RECHT_ZIEL = 'legal'

# Reihenfolge wie in der App (LegalDoc).
RECHTSTEXTE = (
    ('impressum', 'Impressum', 'Wer die App anbietet'),
    ('datenschutz', 'Datenschutz', 'Was gespeichert wird — und was nicht'),
    ('agb', 'AGB', 'Bedingungen für Nutzung und Käufe'),
    ('widerruf', 'Widerruf', 'Dein Widerrufsrecht bei Käufen'),
)

# Renderer, die dieser Build nie anfordert, plus Symboldateien fuer die
# Fehlersuche.
UEBERFLUESSIG = ('skwasm', 'wimp', 'webparagraph')
WORKER = 'tessa_sw.js'


def kopiere():
    if os.path.exists(ZIEL):
        shutil.rmtree(ZIEL)
    shutil.copytree(QUELLE, ZIEL)


def duenne_aus():
    pfad = os.path.join(ZIEL, 'canvaskit')
    entfernt = 0
    for name in list(os.listdir(pfad)):
        ganz = os.path.join(pfad, name)
        if name.startswith(UEBERFLUESSIG) or name.endswith('.symbols'):
            entfernt += groesse(ganz)
            shutil.rmtree(ganz) if os.path.isdir(ganz) else os.remove(ganz)
    return entfernt


def groesse(pfad):
    if os.path.isfile(pfad):
        return os.path.getsize(pfad)
    return sum(
        os.path.getsize(os.path.join(wurzel, datei))
        for wurzel, _, dateien in os.walk(pfad)
        for datei in dateien
    )


def dateiliste():
    dateien = []
    for wurzel, _, namen in os.walk(ZIEL):
        for name in namen:
            ganz = os.path.join(wurzel, name)
            relativ = os.path.relpath(ganz, ZIEL).replace(os.sep, '/')
            if relativ in (WORKER, '.nojekyll'):
                continue
            dateien.append(relativ)
    return sorted(dateien)


def fingerabdruck(dateien):
    """Aendert sich, sobald sich irgendeine Datei aendert — damit der Browser
    die alte Fassung verwirft."""
    summe = hashlib.sha256()
    for relativ in dateien:
        with open(os.path.join(ZIEL, relativ), 'rb') as datei:
            summe.update(relativ.encode())
            summe.update(datei.read())
    return summe.hexdigest()[:12]


def schreibe_worker(dateien):
    eintraege = ',\n'.join("  '%s'" % d for d in ['./'] + dateien)
    inhalt = """// Erzeugt von tool/make_web.py — nicht von Hand aendern.
//
// Legt beim ersten Besuch alles ab und liefert danach aus dem Speicher. Damit
// laeuft Tessa auch ohne Verbindung, etwa vom Startbildschirm des Telefons.
const VERSION = '%s';
const SPEICHER = 'tessa-' + VERSION;
const DATEIEN = [
%s
];

self.addEventListener('install', (ereignis) => {
  ereignis.waitUntil((async () => {
    const speicher = await caches.open(SPEICHER);
    await speicher.addAll(DATEIEN);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (ereignis) => {
  ereignis.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name !== SPEICHER) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (ereignis) => {
  const anfrage = ereignis.request;
  if (anfrage.method !== 'GET') return;
  // Fremde Server bleiben unangetastet.
  if (new URL(anfrage.url).origin !== self.location.origin) return;

  ereignis.respondWith((async () => {
    const speicher = await caches.open(SPEICHER);
    const treffer = await speicher.match(anfrage, { ignoreSearch: true });
    if (treffer) return treffer;

    try {
      const antwort = await fetch(anfrage);
      if (antwort.ok) speicher.put(anfrage, antwort.clone());
      return antwort;
    } catch (fehler) {
      // Ohne Verbindung und ohne Ablage: beim Seitenaufruf die Startseite.
      if (anfrage.mode === 'navigate') {
        const start = await speicher.match('index.html');
        if (start) return start;
      }
      throw fehler;
    }
  })());
});
""" % (fingerabdruck(dateien), eintraege)
    with open(os.path.join(ZIEL, WORKER), 'w', encoding='utf-8') as datei:
        datei.write(inhalt)


# --- Rechtstexte als Webseiten ------------------------------------------------
#
# Dieselben Regeln wie lib/ui/legal/markdown.dart: Absaetze werden
# zusammengezogen, ein Rueckstrich am Zeilenende haelt einen Umbruch.

PUNKT = re.compile(r'^[-*]\s+')
SCHRITT = re.compile(r'^\d+\.\s+')

SEITE = """<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(titel)s — Tessa</title>
<style>
  :root { color-scheme: dark; }
  body {
    margin: 0; padding: 28px 20px 64px;
    background: #0E1118; color: #E7ECF5;
    font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          sans-serif;
  }
  main { max-width: 40rem; margin: 0 auto; }
  h1 { font-size: 1.6rem; margin: 0 0 .6rem; }
  h2 { font-size: 1.05rem; margin: 1.8rem 0 .4rem; }
  a { color: #6BE3C4; }
  ul, ol { padding-left: 1.3rem; }
  li { margin-bottom: .4rem; }
  nav { margin-bottom: 1.6rem; font-size: .9rem; }
  nav a { margin-right: 1rem; }
  footer { margin-top: 3rem; font-size: .85rem; color: #8A93A6; }
</style>
</head>
<body>
<main>
<nav>%(nav)s</nav>
%(inhalt)s
<footer>Tessa — Block-Puzzle. <a href="../">Zum Spiel</a></footer>
</main>
</body>
</html>
"""


def lies_betreiber():
    pfad = os.path.join(RECHT_QUELLE, 'betreiber.json')
    with open(pfad, encoding='utf-8') as datei:
        daten = json.load(datei)

    ust = daten.get('umsatzsteuerId', '').strip()
    daten['umsatzsteuerHinweis'] = (
        'Kleinunternehmer im Sinne von § 19 UStG. Es wird keine '
        'Umsatzsteuer ausgewiesen.' if not ust else
        'Umsatzsteuer-Identifikationsnummer gemäß § 27a UStG: ' + ust)
    return daten


def ist_ausgefuellt(betreiber):
    """Wie Betreiber.istAusgefuellt in Dart: eckige Klammern sind Platzhalter."""
    pflicht = ('name', 'strasse', 'ort', 'email')
    return all(betreiber.get(feld, '').strip() and '[' not in betreiber[feld]
               for feld in pflicht)


def setze_ein(text, betreiber):
    for schluessel in ('name', 'strasse', 'ort', 'land', 'email', 'stand',
                       'umsatzsteuerHinweis'):
        text = text.replace('{{%s}}' % schluessel,
                            betreiber.get(schluessel, ''))
    return text


def schmuecke(text):
    """Macht aus Text HTML: Sonderzeichen schuetzen, dann Fettschrift, Adressen
    und nackte Verweise wieder sichtbar machen."""
    sicher = html.escape(text)
    sicher = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', sicher)
    sicher = re.sub(r'(https?://[^\s<]+)', r'<a href="\1">\1</a>', sicher)
    sicher = re.sub(r'(?<![\w.@-])([\w.+-]+@[\w-]+\.[\w.]+)',
                    r'<a href="mailto:\1">\1</a>', sicher)
    return sicher


def zu_html(quelle):
    """Dieselbe Zerlegung wie parseLegal() in Dart."""
    teile = []
    for roh in quelle.replace('\r\n', '\n').split('\n\n'):
        zeilen = [z.rstrip() for z in roh.split('\n') if z.strip()]
        if not zeilen:
            continue
        erste = zeilen[0].lstrip()

        if erste.startswith('## '):
            teile.append('<h2>%s</h2>' % schmuecke(erste[3:].strip()))
        elif erste.startswith('# '):
            teile.append('<h1>%s</h1>' % schmuecke(erste[2:].strip()))
        elif PUNKT.match(erste):
            teile.append(liste('ul', eintraege(zeilen, PUNKT)))
        elif SCHRITT.match(erste):
            teile.append(liste('ol', eintraege(zeilen, SCHRITT)))
        else:
            teile.append('<p>%s</p>' %
                         '<br>'.join(schmuecke(z) for z in absatz(zeilen)))
    return '\n'.join(teile)


def eintraege(zeilen, marke):
    ergebnis = []
    for zeile in zeilen:
        ohne_rand = zeile.lstrip()
        if marke.match(ohne_rand):
            ergebnis.append(marke.sub('', ohne_rand, count=1).strip())
        elif ergebnis:
            ergebnis[-1] = (ergebnis[-1] + ' ' + ohne_rand).strip()
        else:
            ergebnis.append(ohne_rand)
    return ergebnis


def absatz(zeilen):
    """Zieht die Zeilen zusammen; ein Rueckstrich am Ende haelt den Umbruch."""
    ergebnis, laufend = [], ''
    for zeile in zeilen:
        hart = zeile.endswith('\\')
        stueck = (zeile[:-1] if hart else zeile).strip()
        laufend = stueck if not laufend else laufend + ' ' + stueck
        if hart:
            ergebnis.append(laufend)
            laufend = ''
    if laufend:
        ergebnis.append(laufend)
    return ergebnis


def liste(art, eintraege_):
    punkte = '\n'.join('  <li>%s</li>' % schmuecke(e) for e in eintraege_)
    return '<%s>\n%s\n</%s>' % (art, punkte, art)


def schreibe_recht():
    """Legt docs/legal/ an. Gibt zurueck, wie viele Seiten entstanden sind.

    Solange betreiber.json Platzhalter enthaelt, entsteht nichts: ein
    oeffentliches Impressum mit "[DEIN VOLLER NAME]" waere schlimmer als gar
    keins.
    """
    betreiber = lies_betreiber()
    if not ist_ausgefuellt(betreiber):
        return 0

    ordner = os.path.join(ZIEL, RECHT_ZIEL)
    os.makedirs(ordner, exist_ok=True)

    def nav(aktuell):
        verweise = ['<a href="./">Übersicht</a>']
        for name, titel, _ in RECHTSTEXTE:
            if name != aktuell:
                verweise.append('<a href="%s.html">%s</a>' % (name, titel))
        return '\n'.join(verweise)

    for name, titel, _ in RECHTSTEXTE:
        with open(os.path.join(RECHT_QUELLE, name + '.md'),
                  encoding='utf-8') as datei:
            quelle = setze_ein(datei.read(), betreiber)
        schreibe(os.path.join(ordner, name + '.html'),
                 SEITE % {'titel': titel, 'nav': nav(name),
                          'inhalt': zu_html(quelle)})

    punkte = '\n'.join(
        '  <li><a href="%s.html">%s</a> — %s</li>' % (name, titel, zweck)
        for name, titel, zweck in RECHTSTEXTE)
    uebersicht = ('<h1>Rechtliches</h1>\n<p>Anbieter: %s, %s, %s.</p>\n'
                  '<ul>\n%s\n</ul>'
                  % (html.escape(betreiber['name']),
                     html.escape(betreiber['strasse']),
                     html.escape(betreiber['ort']), punkte))
    schreibe(os.path.join(ordner, 'index.html'),
             SEITE % {'titel': 'Rechtliches', 'nav': '<a href="../">Zum Spiel</a>',
                      'inhalt': uebersicht})
    return len(RECHTSTEXTE) + 1


def schreibe(pfad, inhalt):
    with open(pfad, 'w', encoding='utf-8') as datei:
        datei.write(inhalt)


if __name__ == '__main__':
    kopiere()
    gespart = duenne_aus()
    seiten = schreibe_recht()
    if not seiten:
        print('ACHTUNG: assets/legal/betreiber.json ist noch eine Vorlage — '
              'docs/legal/ bleibt leer. Die Stores verlangen eine erreichbare '
              'Datenschutzerklaerung.')
    dateien = dateiliste()
    schreibe_worker(dateien)
    open(os.path.join(ZIEL, '.nojekyll'), 'w').close()
    print('%d Dateien, %.1f MB — %.1f MB ausgeduennt, %d Rechtsseiten'
          % (len(dateien), groesse(ZIEL) / 1e6, gespart / 1e6, seiten))
