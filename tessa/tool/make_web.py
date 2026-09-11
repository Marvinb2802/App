"""Macht aus dem Flutter-Web-Build die auslieferbare Fassung unter docs/.

Drei Dinge, die der Build allein nicht erledigt:

1. CanvasKit ausduennen. Der Build legt jede Renderer-Variante ab (37 MB),
   gebraucht wird bei "renderer: canvaskit" nur canvaskit selbst und die
   Chromium-Fassung.
2. Einen Service Worker erzeugen. Flutters mitgelieferter meldet sich seit
   Version 3.x selbst ab und speichert nichts zwischen — ohne eigenen gibt es
   kein Offline-Spielen.
3. .nojekyll setzen, damit GitHub Pages die Dateien unveraendert ausliefert.

Vorher bauen:

    flutter build web --release --base-href /App/ --no-web-resources-cdn

Dann:

    python3 tool/make_web.py
"""

import hashlib
import os
import shutil

QUELLE = 'build/web'
ZIEL = '../docs'

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


if __name__ == '__main__':
    kopiere()
    gespart = duenne_aus()
    dateien = dateiliste()
    schreibe_worker(dateien)
    open(os.path.join(ZIEL, '.nojekyll'), 'w').close()
    print('%d Dateien, %.1f MB — %.1f MB ausgeduennt'
          % (len(dateien), groesse(ZIEL) / 1e6, gespart / 1e6))
