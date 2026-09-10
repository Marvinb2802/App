# Tessa — Block-Puzzle

Dauerhafte Projektreferenz. Diese Datei ist die Quelle der Wahrheit für Regeln,
Fairness und Aufbau. Bei Widersprüchen zwischen Code und diesem Dokument gilt das
Dokument, bis es ausdrücklich geändert wird.

Das Verzeichnis `tessa/` ist das Spielprojekt; das umgebende Repository enthält
daneben die Web-App Pacer. Beide teilen keinen Code.

## Spielregeln

- **Raster:** 8×8. Drei Teile liegen gleichzeitig in der Hand, Platzierung per
  Drag-and-Drop.
- **Keine Rotation.** Teile werden so gelegt, wie sie in der Hand liegen.
  (Ein späterer Rotations-Modus ist vorgesehen, aber nicht Teil des Grundspiels —
  er wird als eigener Modus umgesetzt, nicht als Änderung dieser Regel.)
- **Auflösung:** Eine vollständig gefüllte Reihe oder Spalte löst sich auf.
  Reihen und Spalten werden im selben Zug gemeinsam ausgewertet.
- **Punkte:**
  - 1 Punkt je platzierter Zelle,
  - zusätzlich `10 × L × L × Combo`, wenn in einem Zug `L` Linien gleichzeitig
    aufgelöst werden.
- **Combo:** steigt bei jeder Auflösung um 1, Obergrenze 9. Ein Zug ohne
  Auflösung setzt sie auf 1 zurück.
- **Nachschub:** Eine neue Hand kommt erst, wenn alle drei Teile platziert sind.
- **Game over:** wenn kein Teil der verbliebenen Hand mehr an irgendeiner Stelle
  passt.
- **Undo:** drei pro Runde. **Kein Werbe-Revive**, kein Weiterspielen gegen Geld
  oder Werbung.

## Fairness-Garantie (harte Regel, nie brechen)

**Die Steinsequenz wird ausschließlich aus dem Seed erzeugt.** Sie darf niemals
von Punktzahl, Spieldauer, Gerät, Kaufhistorie oder Werbeinteraktion abhängen.
Jeder Code, der das verletzen würde, wird abgelehnt.

So wird die Regel im Aufbau durchgesetzt:

- Die Erzeugung ist eine reine Funktion `hand(seed, index) → drei Teile`. Gleicher
  Seed und gleicher Index ergeben immer dieselbe Hand — unabhängig davon, was auf
  dem Brett steht oder wie das Spiel bisher lief.
- `lib/domain/generation/` bekommt **keinen** Zugriff auf Spielstand, Punktzahl,
  Uhrzeit, Zufallsquellen des Systems, Geräteinformationen, Telemetrie, Kauf- oder
  Werbe-Zustand. Als Eingabe existieren nur Seed und laufender Index.
- Kein globaler `Random()` ohne Seed, kein `DateTime.now()`, keine
  Plattformkanäle in `domain/`.
- Jede Änderung an der Erzeugung braucht einen Test, der zeigt: derselbe Seed
  liefert dieselbe Sequenz. Ein Test hält zusätzlich eine bekannte Sequenz für
  einen festen Seed fest, damit unbeabsichtigte Änderungen auffallen.
- Der Seed einer Runde wird gespeichert und ist im Spiel einsehbar, damit eine
  Runde nachspielbar und überprüfbar ist.

Schwierigkeit darf über die Formen im Katalog und deren Gewichtung eingestellt
werden — aber nur seedabhängig und für alle gleich, nie reaktiv auf den Verlauf
einer einzelnen Partie.

## Technik

- **Flutter**, Zielgröße der App unter 60 MB. Abhängigkeiten sparsam halten;
  Größe mit `flutter build apk --analyze-size` prüfen, Auslieferung mit
  `--split-per-abi`.
- **State:** Riverpod.
- **Lokale Persistenz:** sqflite. **Kein Pflicht-Login**, kein Konto nötig.
- **Vollständig offline spielbar.** Keine Netzwerkanfrage darf für das Spielen
  erforderlich sein.
- **Tests:** `flutter test`. Vor jedem Commit zusätzlich `flutter analyze`.

## Ordnerstruktur (Vorschlag)

Abhängigkeiten zeigen nur nach innen: `ui → application → domain` und
`data → domain`. `domain/` importiert weder Flutter noch `data/`, `application/`
oder `ui/` — dadurch bleibt die Spiellogik rein, deterministisch und schnell
testbar, was die Fairness-Garantie überhaupt erst überprüfbar macht.

```
tessa/
├─ CLAUDE.md
├─ pubspec.yaml
├─ lib/
│  ├─ main.dart                    Einstieg: ProviderScope + App
│  ├─ app.dart                     MaterialApp, Routing, Theme-Bindung
│  ├─ domain/                      reines Dart: keine Flutter-Importe, keine I/O
│  │  ├─ model/
│  │  │  ├─ board.dart             8×8-Raster, unveränderlich
│  │  │  ├─ piece.dart             Form als Menge belegter Zellen
│  │  │  ├─ piece_catalog.dart     feste Liste aller Formen samt Gewichtung
│  │  │  ├─ hand.dart              drei Teile und ihr Platzierungsstatus
│  │  │  └─ game_state.dart        Brett, Hand, Punkte, Combo, Undo-Rest, Seed
│  │  ├─ rules/
│  │  │  ├─ placement.dart         Passt ein Teil an eine Position?
│  │  │  ├─ clearing.dart          volle Reihen und Spalten finden und räumen
│  │  │  ├─ scoring.dart           Punktformel inklusive Combo
│  │  │  └─ game_over.dart         kein Teil der Hand passt mehr irgendwo
│  │  └─ generation/
│  │     ├─ seeded_random.dart     deterministischer PRNG, fest im Code
│  │     └─ piece_sequence.dart    hand(seed, index) — Kern der Fairness-Garantie
│  ├─ application/                 Riverpod: Zustand und Abläufe
│  │  ├─ game_controller.dart      Zug ausführen, Undo, neue Runde
│  │  ├─ drag_controller.dart      laufender Zug: Zielzelle, Vorschau, Abbruch
│  │  └─ providers.dart            alle Provider-Definitionen an einer Stelle
│  ├─ data/                        Persistenz
│  │  ├─ database.dart             sqflite öffnen, Migrationen
│  │  ├─ game_dao.dart             laufende Partie sichern und laden
│  │  ├─ score_dao.dart            Bestenliste, Statistik
│  │  └─ settings_repository.dart  Einstellungen
│  ├─ ui/
│  │  ├─ screens/                  home, game, scores, settings
│  │  ├─ widgets/                  board_view, piece_tray, score_bar, combo_badge
│  │  └─ theme/                    Farben, Maße, Animationsdauern
│  └─ l10n/                        Texte (Deutsch zuerst)
└─ test/
   ├─ domain/                      Schwerpunkt: Regeln, Punkte, Sequenz-Determinismus
   ├─ application/                 Controller-Verhalten, Undo-Grenzen
   ├─ data/                        Migrationen, Speichern und Laden
   └─ widget/                      Drag-and-Drop, Darstellung
```

## Offene Punkte

Vor der Umsetzung der Punktevergabe zu klären — hier bewusst nicht selbst
entschieden:

1. Zählt beim Bewerten eines Zuges der Combo-Stand **vor** oder **nach** dem
   Erhöhen? (Bringt die erste Auflösung nach einem Reset den Faktor 1 oder 2?)
2. Steigt die Combo **je Zug mit Auflösung** um 1 oder **je aufgelöster Linie**?
   (Bei `L = 3`: +1 oder +3?)
3. Bezieht sich „drei Undo pro Runde" auf eine Partie bis zum Game over? Nimmt
   ein Undo auch Combo-Stand und Position in der Steinsequenz zurück?
