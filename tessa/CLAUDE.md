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
- **Wortwahl:** Was im Code `seed` heißt, heißt in der Oberfläche
  **Spielcode** — verständlicher für Spielende. Im Code bleibt `seed`.
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

## Spielarten

- **Normale Runde:** zufälliger Spielcode.
- **Tagesrätsel:** der Spielcode kommt aus dem Datum (10.09.2026 → 20260910).
  Alle spielen am selben Tag dieselbe Runde. Eine Serie zählt, an wie vielen
  Tagen in Folge gespielt wurde; ein ausgelassener Tag setzt sie zurück.
- **Tüfteln:** derselbe Spielcode, aber **unbegrenzt zurück**. Weil der Code
  die ganze Steinfolge festlegt, ist eine Runde ein lösbares Rätsel — dieser
  Modus lädt ein, sie auszureizen. Das ist der eigentliche Vorteil der
  Fairness-Garantie gegenüber Spielen mit verstecktem Zufall.

**Hinweise:** drei je Runde (im Tüftel-Modus unbegrenzt). `findHint` sucht den
Zug, der die meisten Linien auflöst, bei Gleichstand den zuerst gefundenen —
derselbe Spielstand ergibt also immer denselben Vorschlag.

## Technik

- **Flutter**, Zielgröße der App unter 60 MB. Abhängigkeiten sparsam halten;
  Größe mit `flutter build apk --analyze-size` prüfen, Auslieferung mit
  `--split-per-abi`.
- **State:** Riverpod.
- **Lokale Persistenz:** sqflite auf dem Gerät. Wo es das nicht gibt (Browser),
  springt `PrefsStore` über `shared_preferences` ein — beide erfüllen dieselbe
  Schnittstelle `TessaStore`, die Oberfläche kennt den Unterschied nicht.
  **Kein Pflicht-Login**, kein Konto nötig.
- **Aussehen:** dunkel, ein Theme (`tessaTheme()`), kein Umschalten.
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
│  │  │  ├─ hint.dart              sucht den besten Zug
│  │  │  └─ move.dart              ein vollständiger Zug: Regeln zusammengesetzt
│  │  └─ generation/
│  │     ├─ seeded_random.dart     deterministischer PRNG, fest im Code
│  │     └─ piece_sequence.dart    hand(seed, index) — Kern der Fairness-Garantie
│  ├─ application/                 Riverpod: Zustand und Abläufe
│  │  ├─ game_controller.dart      Zug ausführen, Undo, neue Runde
│  │  ├─ drag_controller.dart      laufender Zug: Zielzelle, Vorschau, Abbruch
│  │  └─ providers.dart            Provider an einer Stelle, samt Seed-Quelle
│  ├─ data/                        Persistenz
│  │  ├─ store.dart                TessaStore: was gespeichert werden muss
│  │  ├─ prefs_store.dart          Speicher für den Browser
│  │  ├─ database.dart             sqflite öffnen, Schema, Migrationen
│  │  ├─ game_dao.dart             laufende Partie sichern und laden
│  │  ├─ score_dao.dart            Bestenliste mit Seed je Runde
│  │  └─ settings_repository.dart  Einstellungen als Schlüssel-Wert-Paare
│  ├─ ui/
│  │  ├─ screens/                  home_screen (Einstieg), game_screen samt
│  │  │                            Abschlussanzeige, scores_screen,
│  │  │                            stats_screen (Zahlen und Einstellungen)
│  │  ├─ widgets/                  board_view, piece_tray, piece_view,
│  │  │                            cell_tile, score_bar, move_feedback
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
- Die Bestenliste ist sichtbar: erreichbar aus der Punkteleiste und von der
  Abschlussanzeige, mit Seed und Datum je Runde. Jeder Eintrag lässt sich mit
  seinem Seed noch einmal spielen.
- Der Startbildschirm ist der Einstieg: laufende Runde fortsetzen, neue Runde,
  Bestenliste, Bestpunktzahl — und „Runde mit Seed spielen", damit sich eine
  Runde gezielt nachspielen lässt.
- Nach einer Auflösung steht über dem Brett, was der Zug gebracht hat: Punkte,
  Zahl der gefallenen Linien und der angewandte Combo-Faktor.
- Gefallene Linien leuchten auf dem Brett kurz nach (420 ms: aufleuchten,
  leicht aufblähen, verblassen). Ausgelöst wird das nur von einem *neuen* Zug —
  ein Undo holt einen älteren Zug zurück und darf nichts blinken lassen.
  Die Dauer steht als `BoardView.flashDuration` an einer Stelle.
- Ein gelegtes Teil springt auf (220 ms, `BoardView.popDuration`): die frisch
  belegten Zellen fangen klein an und rasten mit leichtem Überschwingen ein.
  Zellen, die im selben Zug wieder gefallen sind, springen nicht auf — sie
  gehören zum Nachleuchten. Dafür führt `MoveOutcome` die belegten Zellen mit,
  nicht nur ihre Anzahl (`placedCellCount`).
- Zurück-Knopf in der Spielleiste, Ergebnis-Teilen über die Zwischenablage,
  Statistik (Runden, Bestwert, Durchschnitt, Serie) und abschaltbare Vibration.
- Noch offen: **Töne**. Dafür braucht es Klangdateien und ein Paket; das ist
  bewusst der nächste Schritt, nicht Teil dieses Standes.
- Tempo und Stärke beider Animationen sind nach Gefühl gesetzt und in der
  Entwicklungsumgebung von niemandem gesehen worden. Sie gehören am Gerät
  nachjustiert: `flashDuration`, `popDuration` und die beiden Faktoren in
  `_clearFlash` und `_maybePop`.

`Size.fromHeight(x)` als `minimumSize` einer Schaltfläche bedeutet
*unendliche* Mindestbreite. Das sprengt jeden Knopf, der nicht in einer
breitenbegrenzten Spalte sitzt. Feste Mindestbreite verwenden.

Reine Dart-Tests, die Vibration auslösen, brauchen
`TestWidgetsFlutterBinding.ensureInitialized()` — sonst fehlt der
Plattformkanal.

Beim Prüfen von Animationen im Test: `Matrix4.getMaxScaleOnAxis()` nimmt die
Z-Achse mit, die bei `Transform.scale` immer 1 bleibt — Werte unter 1 sind
damit nicht messbar. Der tatsächliche Faktor steht in `transform.entry(0, 0)`.

## Tests

`flutter test` deckt alle vier Schichten ab. Drei Tests sind Wächter — sie
sollen anschlagen, wenn eine Regel dieses Dokuments verletzt wird, und wurden
jeweils gegen eine absichtlich eingebaute Verletzung geprüft:

- `test/domain/fairness_guard_test.dart` hält `generation/` frei von Uhr,
  System, Flutter und jedem Paketimport.
- `piece_sequence_test.dart` hält eine bekannte Sequenz fest: ändert sich diese
  Liste, ändert sich für alle Spielenden die Steinsequenz.
- `game_screen_test.dart` prüft die Punkteleiste auf einem schmalen Gerät mit
  größtmöglichem Seed auf Überlauf.

Widget-Tests gegen die Datenbank brauchen `databaseFactoryFfiNoIsolate` —
nur so laufen die Futures in der künstlichen Zeit eines Widget-Tests zu Ende.

Widget-Tests mounten den Bildschirm, um den es geht, direkt in einer
`MaterialApp` — nicht `TessaApp`, deren Einstieg der Startbildschirm ist.
Nur `home_screen_test.dart` startet die ganze App.
