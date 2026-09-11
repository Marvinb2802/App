# Tessa

Ein Block-Puzzle in Flutter. 8×8-Raster, drei Teile in der Hand, volle Reihen
und Spalten lösen sich auf.

Das Besondere: **Die Steinfolge einer Runde steht von Anfang an fest** und
ergibt sich allein aus dem Spielcode. Dadurch lässt sich jede Runde nachspielen,
vergleichen und ausreizen — siehe `CLAUDE.md`.

## Spielen ohne Installation

Die Web-Fassung liegt unter `../docs/` und wird über GitHub Pages ausgeliefert.
Sie lässt sich auf den Startbildschirm legen (Safari: Teilen → „Zum
Home-Bildschirm") und läuft dann **auch ohne Internet**. Im Browser fehlen
Vibration und Käufe; alles andere funktioniert.

Neu bauen und ausliefern:

```bash
flutter build web --release --base-href /App/ --no-web-resources-cdn
python3 tool/make_web.py
```

`make_web.py` dünnt CanvasKit aus, erzeugt den Service Worker mit der
Dateiliste fürs Offline-Spielen und setzt `.nojekyll`.

## Auf dem eigenen Rechner starten

```bash
flutter pub get
flutter run            # angeschlossenes Gerät oder Emulator
flutter run -d chrome  # im Browser
```

## Auf dem Handy installieren

**Android** — eine Datei zum Draufziehen:

```bash
flutter build apk --release
# liegt danach in build/app/outputs/flutter-apk/app-release.apk
```

Die APK auf das Handy kopieren und öffnen. Android fragt einmal nach der
Erlaubnis, Apps aus unbekannter Quelle zu installieren.

Für den Play Store stattdessen ein App Bundle, kleiner und signiert:

```bash
flutter build appbundle --release
```

**iPhone und iPad** — geht nur mit einem Mac und Xcode:

```bash
flutter build ipa
```

Zum Ausprobieren auf dem eigenen Gerät genügt ein kostenloses Apple-Konto; für
den App Store braucht es ein Entwicklerprogramm.

## Prüfen

```bash
flutter test      # alle Tests
flutter analyze   # statische Prüfung
```

## Kennungen

| | |
|---|---|
| Paket-Kennung | `de.marvinb.tessa` |
| Anzeigename | Tessa |
| Version | steht in `pubspec.yaml` unter `version:` |

Die Paket-Kennung lässt sich nach einer Veröffentlichung **nicht mehr ändern**.

## Symbol

Das App-Symbol wird erzeugt, nicht gezeichnet:

```bash
python3 tool/make_icon.py          # braucht Pillow
dart run flutter_launcher_icons    # verteilt es auf alle Plattformen
```
