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
  - Bewertet wird mit dem Combo-Stand **vor** dem Erhöhen: die erste Auflösung
    nach einem Reset zählt mit Faktor 1.
- **Combo:** steigt bei jeder Auflösung um 1, Obergrenze 9. Ein Zug ohne
  Auflösung setzt sie auf 1 zurück. Sie steigt **einmal je Zug mit Auflösung,
  nicht je Linie** — `L` geht bereits quadratisch in die Formel ein.
- **Nachschub:** Eine neue Hand kommt erst, wenn alle drei Teile platziert sind.
- **Game over:** wenn kein Teil der verbliebenen Hand mehr an irgendeiner Stelle
  passt.
- **Undo:** drei pro Runde; eine Runde ist eine Partie bis zum Game over. Ein
  Undo stellt den vorherigen Spielstand **vollständig** wieder her — Brett, Hand,
  Punkte, Combo und Position in der Steinsequenz — und verbraucht einen der drei
  Versuche. Die Sequenzposition mitzunehmen ist Teil der Fairness: bliebe sie
  stehen, ließe sich per Undo die nächste Hand abgreifen.
  **Kein Werbe-Revive**, kein Weiterspielen gegen Geld oder Werbung.

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
- Nur die *Wahl* des Seeds darf zufällig sein (`seedSourceProvider`). Sobald er
  feststeht, folgt die ganze Runde aus ihm — das ist kein Widerspruch zur
  Garantie, sondern ihre Voraussetzung.

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
│  │  │  ├─ cell.dart              Position im Raster
│  │  │  ├─ board.dart             8×8-Raster, unveränderlich
│  │  │  ├─ piece.dart             Form als Menge belegter Zellen
│  │  │  ├─ piece_catalog.dart     feste Liste aller Formen samt Gewichtung
│  │  │  ├─ hand.dart              drei Teile und ihr Platzierungsstatus
│  │  │  └─ game_state.dart        Brett, Hand, Punkte, Combo, Undo-Rest, Seed
│  │  ├─ rules/
│  │  │  ├─ placement.dart         Passt ein Teil an eine Position?
│  │  │  ├─ clearing.dart          volle Reihen und Spalten finden und räumen
│  │  │  ├─ scoring.dart           Punktformel inklusive Combo
│  │  │  ├─ game_over.dart         kein Teil der Hand passt mehr irgendwo
│  │  │  └─ move.dart              ein vollständiger Zug: Regeln zusammengesetzt
│  │  └─ generation/
│  │     ├─ seeded_random.dart     deterministischer PRNG, fest im Code
│  │     └─ piece_sequence.dart    hand(seed, index) — Kern der Fairness-Garantie
│  ├─ application/                 Riverpod: Zustand und Abläufe
│  │  ├─ game_controller.dart      Zug ausführen, Undo, neue Runde
│  │  ├─ drag_controller.dart      laufender Zug: Zielzelle, Vorschau, Abbruch
│  │  └─ providers.dart            Provider an einer Stelle, samt Seed-Quelle
│  ├─ data/                        Persistenz
│  │  ├─ database.dart             sqflite öffnen, Schema, Migrationen
│  │  ├─ game_dao.dart             laufende Partie sichern und laden
│  │  ├─ score_dao.dart            Bestenliste mit Seed je Runde
│  │  └─ settings_repository.dart  Einstellungen als Schlüssel-Wert-Paare
│  ├─ ui/
│  │  ├─ screens/                  game_screen samt Abschlussanzeige
│  │  ├─ widgets/                  board_view, piece_tray, piece_view,
│  │  │                            cell_tile, score_bar
│  │  └─ theme/                    Farben, Maße, Animationsdauern
│  └─ l10n/                        Texte (Deutsch zuerst)
└─ test/
   ├─ domain/                      Schwerpunkt: Regeln, Punkte, Sequenz-Determinismus
   ├─ application/                 Controller-Verhalten, Undo-Grenzen
   ├─ data/                        Migrationen, Speichern und Laden
   └─ widget/                      Drag-and-Drop, Darstellung
```

## Stand der Umsetzung

- `domain/` steht vollständig und ist mit `flutter test` abgedeckt: Modelle,
  Regeln, Punkte, Game-over und die seedbasierte Erzeugung.
- `application/` steht: `GameController` (Zug, Undo, Neustart, Replay mit
  demselben Seed) und `DragController` samt Vorschau. Die Seed-Quelle ist ein
  Provider und in Tests durch einen festen Wert ersetzbar.
- `ui/` steht: Brett mit Drag-and-Drop und Zielvorschau (auch für unerlaubte
  Züge), Ablage der drei Teile, Punkteleiste mit Combo, Undo und sichtbarem
  Seed, dazu die Abschlussanzeige mit „neue Runde" und „dieselbe noch einmal".
  Ein Widget-Test zieht ein Teil wirklich per Geste aufs Brett.
- `data/` steht: sqflite mit drei Tabellen (laufende Partie, Bestenliste,
  Einstellungen). Die Partie wird nach jedem Zug gesichert und beim Start
  fortgesetzt; eine beendete Runde wandert in die Bestenliste und die laufende
  Partie wird weggeräumt. Getestet wird gegen `sqflite_common_ffi` im
  Arbeitsspeicher, ohne Gerät.
- Ohne Datenbank läuft Tessa weiter, nur ohne Sichern — `main()` fängt das ab,
  und `databaseProvider` ist ohne Datenbank schlicht null.
- Der Undo-Verlauf wird nicht mitgesichert: nach einem Neustart der App gibt es
  nichts zurückzunehmen, die Zahl der Versuche bleibt aber erhalten.
- Noch offen: Animationen beim Auflösen, Startbildschirm, eine Ansicht für die
  Bestenliste, Anzeige der gefallenen Linien.
