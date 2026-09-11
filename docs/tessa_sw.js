// Erzeugt von tool/make_web.py — nicht von Hand aendern.
//
// Legt beim ersten Besuch alles ab und liefert danach aus dem Speicher. Damit
// laeuft Tessa auch ohne Verbindung, etwa vom Startbildschirm des Telefons.
const VERSION = '625989de53d2';
const SPEICHER = 'tessa-' + VERSION;
const DATEIEN = [
  './',
  '.last_build_id',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/NOTICES',
  'assets/assets/sounds/clear1.wav',
  'assets/assets/sounds/clear2.wav',
  'assets/assets/sounds/clear3.wav',
  'assets/assets/sounds/clear4.wav',
  'assets/assets/sounds/clear5.wav',
  'assets/assets/sounds/clear6.wav',
  'assets/assets/sounds/clear7.wav',
  'assets/assets/sounds/clear8.wav',
  'assets/assets/sounds/clear9.wav',
  'assets/assets/sounds/gameover.wav',
  'assets/assets/sounds/place.wav',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/fonts/fallback/Roboto-Regular.ttf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'assets/shaders/ink_sparkle.frag',
  'assets/shaders/stretch_effect.frag',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.js.symbols',
  'canvaskit/chromium/canvaskit.wasm',
  'favicon.png',
  'flutter.js',
  'flutter_bootstrap.js',
  'flutter_service_worker.js',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'index.html',
  'main.dart.js',
  'manifest.json',
  'version.json'
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
