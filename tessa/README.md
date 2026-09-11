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
Dateiliste fürs Offline-Spielen, legt die Rechtstexte als Webseiten unter
`docs/legal/` ab und setzt `.nojekyll`.

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

## Rechtstexte

Impressum, Datenschutz, AGB und Widerruf liegen als Markdown in
`assets/legal/`. Sie erscheinen in der App unter **Statistik → Rechtliches**
und — sobald die Angaben stehen — als Webseiten unter `docs/legal/`.

Vor einer Veröffentlichung:

1. `assets/legal/betreiber.json` ausfüllen. Alles in eckigen Klammern ist ein
   Platzhalter; solange einer übrig ist, zeigt die App einen Warnhinweis und
   `make_web.py` legt `docs/legal/` nicht an.
2. Die Texte prüfen lassen. Es sind Vorlagen, keine Rechtsberatung.
3. Web-Fassung neu bauen. Die Adressen für die Store-Formulare lauten dann:

   ```
   https://marvinb2802.github.io/App/legal/datenschutz.html
   https://marvinb2802.github.io/App/legal/impressum.html
   https://marvinb2802.github.io/App/legal/agb.html
   https://marvinb2802.github.io/App/legal/widerruf.html
   ```

Apple und Google verlangen eine öffentlich erreichbare Datenschutzerklärung
als Adresse — ein Text nur in der App genügt dort nicht.

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
