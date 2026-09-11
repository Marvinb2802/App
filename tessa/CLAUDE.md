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

## Fairness-Garantie (harte Regel)

**Die Steinsequenz wird ausschließlich aus dem Seed erzeugt.** Sie darf niemals
von Punktzahl, Spieldauer, Gerät oder Werbeinteraktion abhängen. Jeder Code,
der das verletzen würde, wird abgelehnt.

> **Geändert auf Wunsch des Auftraggebers.** Ursprünglich stand hier auch
> „Kaufhistorie", und Käufe durften keinerlei Vorteile bringen. Das gilt nicht
> mehr: Hinweise, zusätzliche Zurück-Züge und Weiterspielen nach dem Ende
> dürfen gekauft werden — mit Sternen oder mit Geld, wie in vergleichbaren
> Spielen üblich.
>
> Was bleibt, ist die Steinfolge selbst. Nicht aus Prinzip, sondern weil sonst
> das Tagesrätsel, der Bestwert je Spielcode und das Nachspielen einer Runde
> ihre Grundlage verlieren: Diese drei Dinge funktionieren nur, solange
> derselbe Spielcode bei allen dieselben Teile liefert.

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
- **Level:** beliebig viele, jedes mit eigenem Spielcode, eigenem Ziel, teils
  vorbelegtem Brett und begrenzten Zügen. Alles hängt allein an der Nummer
  (`domain/model/level.dart`), es gibt also keine Liste zu pflegen. Die Kurve
  steht in `LevelTuning` an einer Stelle.
- **Wochenrätsel:** die sieben Tagesrätsel der laufenden Woche (Montag bis
  Sonntag) mit Gesamtpunktzahl. Vergangene Tage lassen sich nachspielen,
  gewertet wird aber nur der Versuch am Tag selbst.
- **Drehen erlaubt:** die eine Ausnahme von „Teile werden nicht rotiert".
  Antippen dreht, Ziehen legt. Die Drehstufe steht in der Kennung
  (`line3h@1`), damit ein gedrehtes Teil gespeichert und wiederhergestellt
  werden kann.
- **Zen:** kein Spielende. Geht nichts mehr, kommt die nächste Hand *aus der
  Steinfolge*; hilft auch das nicht, wird die vollste Reihe geräumt. Es wird
  nie neu gewürfelt, und die Rettung gibt keine Punkte.
- **Hardcore:** der Gegenentwurf zum Tüfteln — **kein Hinweis, kein Zurück,
  kein Weiterspielen**, auch nicht gekauft. Dazu zwei Verschärfungen, die
  beide für alle gleich sind: die Teile kommen aus `PieceSet.hardcore` (der
  Punkt und die kurzen Balken werden selten, sperrige Formen häufig), und vom
  siebten Zug an fällt **alle drei Züge Geröll** auf ein freies Feld.
  Ergebnisse gehen in einen **eigenen Bestwert**, nicht in die Bestenliste:
  die Steinfolge ist eine andere, die Punktzahlen wären nicht vergleichbar.
  Eine Hardcore-Runde wird **nicht gesichert** — sie läuft in einem Stück. Das
  ist nicht nur Haltung: beim Fortsetzen stünde der Modus nicht mehr fest, und
  aus der harten Runde würde eine gewöhnliche mit drei Undo.
- **Tüfteln:** derselbe Spielcode, aber **unbegrenzt zurück**. Weil der Code
  die ganze Steinfolge festlegt, ist eine Runde ein lösbares Rätsel — dieser
  Modus lädt ein, sie auszureizen. Das ist der eigentliche Vorteil der
  Fairness-Garantie gegenüber Spielen mit verstecktem Zufall.

**Schwierigkeit der Level — an gemessenem Spiel geeicht.** `level_test.dart`
lässt einen Automaten jedes Level spielen: er nimmt den Zug, der die meisten
Linien räumt, und hält bei Gleichstand das Brett offen. In rund 30 Zügen holt
er etwa 250 Punkte, 11 Linien und Combo 3–5 — daran sind die Ziele bemessen,
nicht an Schätzung. Die Tests halten fest: die ersten 25 Level lassen sich
durchspielen, ab Level 60 scheitert der Automat regelmäßig, und höchstens 5 von
120 Leveln fahren sich früh fest (gemessen: 3).

Was der Automat nicht kann: vorausschauende Ziele wie „zwei Linien in einem
Zug" plant er nie, weil er sofort räumt. Für die gilt eine schwächere Zusage —
er muss dem Ziel bis auf eine Linie nahekommen.

Die Vorbelegung wächst als **nahezu volle Reihen von unten**. Zwei frühere
Varianten waren messbar schlechter: verstreute Einzelzellen und ein loser
Sockel führten bei späten Leveln nach vier Zügen zum Ende — nicht schwer,
sondern unfair.

**Wie hart Hardcore wirklich ist — gemessen.** Derselbe Automat wie bei den
Leveln spielt beide Teilesätze. Über 30 Spielcodes: im Grundspiel hält er rund
139 Züge durch und holt 1.260 Punkte, in Hardcore mit Geröll noch 28 Züge und
284 Punkte. Den größten Teil davon macht der Teilesatz (35 Züge ohne Geröll),
das Geröll sorgt dafür, dass auch eine gut laufende Runde ein Ende findet.
Zwei Tests halten beides fest: Hardcore muss mindestens dreimal kürzer sein als
das Grundspiel, und der Automat muss über zehn Züge kommen — schwer ist
gewollt, aussichtslos nicht.

Eine Vorbelegung des Bretts kam nicht dazu: die Messung zeigte, dass sie nur
noch weiter verkürzt hätte, ohne etwas hinzuzufügen.

**Das Geröll und die Fairness-Garantie.** Die Steinfolge bleibt unberührt — sie
kommt weiter allein aus Spielcode und Handindex, und `domain/generation/` fasst
das Geröll nicht an (es liegt in `domain/rules/hardcore.dart`). Wo ein Stein
landet, hängt vom Spielcode, von der Zugnummer und davon ab, welche Felder frei
sind. Gleicher Code und gleiche Züge ergeben denselben Verlauf; eine Runde
bleibt also nachspielbar.

**Tagesziel:** Zusätzlich zur Punktjagd stellt jeder Tag eine Aufgabe (Linien
in einem Zug, Combo-Stand, Punktzahl). Die Auswahl hängt allein vom Datum ab,
ist also wie der Spielcode nachrechenbar.

**Analyse am Rundenende:** Vor jedem Zug wird festgehalten, was der beste
verfügbare Zug gebracht hätte (`findHint`). Am Ende steht da, welcher Zug am
besten war und wo die größte Gelegenheit liegen blieb. Auch das ist nur
möglich, weil die Runde vollständig feststeht.

**Bestwert je Spielcode:** Zu jedem Code wird die eigene beste Runde
festgehalten. Beim Spielen steht der Abstand dazu in der Leiste („noch 600"),
und wer ihn überbietet, sieht es sofort. Erst das macht Tüfteln und das
Nachspielen messbar — bei zufälliger Steinfolge wäre so ein Vergleich sinnlos.

**Hinweise:** drei je Runde — im Tüftel-Modus unbegrenzt, im Hardcore-Modus
keine. `findHint` sucht den Zug, der die meisten Linien auflöst, bei
Gleichstand den zuerst gefundenen — derselbe Spielstand ergibt also immer
denselben Vorschlag.

## Shop — und wo seine Grenze verläuft

Zwei Wege führen zum selben Ergebnis: **Sterne**, verdient durch Spielen
(einer je 250 Punkte, fünf fürs Tagesziel), oder **echtes Geld** über den
App Store.

Angeboten werden:

- **Hinweise** — wirken sofort in der laufenden Runde, auch im Tagesrätsel.
- **Zurück-Züge** — zusätzliche Undos für die laufende Runde.
- **Weiterspielen** — nach dem Ende geht es mit der eigenen Punktzahl weiter;
  Platz entsteht wie im Zen-Modus (nächste Hand aus der Steinfolge, notfalls
  die vollste Reihe räumen).
- **Farbsets** — Kosmetik, dauerhaft.

Die verbliebene Grenze, und warum sie bleibt:

- **Kein Angebot verändert die Steinfolge.** Nicht aus Prinzip, sondern weil
  Tagesrätsel, Bestwert je Spielcode und das Nachspielen einer Runde genau
  davon leben, dass derselbe Spielcode bei allen dieselben Teile liefert.
- Dauerhaft freischalten darf ein Kauf nur Aussehen; alles andere ist
  Verbrauchsgut.
- **Im Hardcore-Modus wirkt gar kein Kauf.** Hinweise und Zurück-Züge lassen
  sich zwar kaufen, bleiben dort aber wirkungslos, und Weiterspielen gibt es
  nicht. Sonst wäre der Modus mit Sternen aushebelbar — und damit keiner.
  `allowsHelp(mode)` ist die eine Stelle, an der diese Zusage hängt;
  `hardcore_test.dart` prüft sie gegen jeden Modus.
- Zwei Wächtertests (`shop_test.dart`, `paid_purchase_test.dart`) schlagen an,
  sobald ein Angebot anders wirkt als hier beschrieben.

### Käufe mit echtem Geld

Der Kaufweg ist gebaut (`data/purchases.dart`, `in_app_purchase`): Angebote
laden, kaufen, **Käufe wiederherstellen** (bei Apple Pflicht). Verkauft wird
ausschließlich Kosmetik — `paid_purchase_test.dart` hat einen Wächter, der
anschlägt, sobald ein bezahltes Angebot etwas anderes freischaltet als ein
Farbset.

Scharf ist das noch nicht, und zwar aus Gründen, die sich nicht im Code lösen
lassen:

- Ein Entwicklerkonto ist nötig (Apple 99 $/Jahr, Google 25 $ einmalig).
- Die Produktkennungen aus `paidItems` müssen in App Store Connect und der
  Play Console angelegt und freigegeben werden.
- Digitale Güter müssen über das Bezahlsystem der Plattform laufen; ein
  eigener Bezahlweg ist dort nicht zulässig.
- Impressum, AGB, Datenschutzerklärung und Widerrufsbelehrung stehen als
  Vorlagen bereit (siehe „Rechtstexte"), sind aber weder ausgefüllt noch
  geprüft; beim Verkauf kommen Gewerbe und Steuer dazu.
- Im Browser gibt es keine Käufe — dort meldet die Oberfläche das offen.

Getestet ist der Ablauf gegen eine Attrappe, nicht gegen einen echten Store.

## Web-Fassung und Offline

Ausgeliefert wird aus `docs/` über GitHub Pages. Der Ablauf steht in
`README.md`; `tool/make_web.py` erledigt dabei vier Dinge, die der
Flutter-Build nicht abnimmt:

- **CanvasKit ausdünnen.** Der Build legt jede Renderer-Variante ab (37 MB).
  Bei `renderer: canvaskit` wird nur CanvasKit selbst und die Chromium-Fassung
  angefordert; der Rest fliegt raus (rund 24 MB gespart).
- **Service Worker erzeugen.** Flutters mitgelieferter Worker *meldet sich seit
  Version 3.x selbst ab* und speichert nichts zwischen — ohne eigenen gibt es
  kein Offline-Spielen. Der erzeugte Worker legt beim ersten Besuch alles ab
  und liefert danach aus dem Speicher; seine Version ist ein Fingerabdruck über
  alle Dateien, damit eine neue Fassung die alte sicher ablöst.
- **Die Rechtstexte als Webseiten ablegen** (`docs/legal/`), aus denselben
  Dateien, die auch die App anzeigt.
- **`.nojekyll`** setzen.

CanvasKit liegt bewusst lokal im Repo (14 MB) statt von Googles CDN zu kommen:
sonst wäre die Seite ohne Verbindung nicht zu öffnen, und der Startbildschirm-
Eintrag auf dem Telefon wäre nutzlos.

## Für echte Geräte

- **Paket-Kennung:** `de.marvinb.tessa`, gesetzt für Android, iOS, macOS und
  Linux. Sie ist nach einer Veröffentlichung **nicht mehr änderbar**. Der
  Platzhalter `de.deinname.tessa` aus `flutter create` wurde ersetzt.
- **Anzeigename:** Tessa (Android-Manifest, iOS `CFBundleName` und
  `CFBundleDisplayName`, Web-Manifest und Seitentitel).
- **Ausrichtung:** Hochformat auf Telefonen; das iPad darf drehen.
- **Startbildschirm** in der Hintergrundfarbe der App (`#0E1118`), damit beim
  Starten nichts weiß aufblitzt — Android `launch_background.xml` und
  `styles.xml`, iOS `LaunchScreen.storyboard`.
- **Symbol:** wird erzeugt, nicht gezeichnet — `tool/make_icon.py` (Pillow)
  malt vier Blöcke in den Spielfarben, `dart run flutter_launcher_icons`
  verteilt sie. Für Android liegt der Vordergrund im inneren Fünftel, weil das
  System die Ecken beschneidet.
- **Nicht geprüft:** In dieser Umgebung gibt es kein Android SDK und kein
  Xcode. `flutter build apk` und `flutter build ipa` sind hier nie gelaufen —
  die Anleitung dazu steht in `README.md`, der erste echte Build muss auf einem
  Rechner mit Werkzeugkette stattfinden.

## Rechtstexte

Impressum, Datenschutzerklärung, AGB und Widerrufsbelehrung liegen als
Markdown in `assets/legal/` und erscheinen an **zwei** Stellen: in der App
(Statistik → Rechtliches) und als Webseiten unter `docs/legal/`. Die Stores
verlangen eine öffentlich erreichbare Datenschutzerklärung als Adresse — ein
Text nur in der App genügt dort nicht.

- **Eine Quelle für die Angaben:** `assets/legal/betreiber.json`. Name,
  Anschrift und E-Mail stehen genau einmal da und werden über Platzhalter
  (`{{name}}`, `{{ort}}`, …) in alle vier Texte eingesetzt. Der Satz zur
  Umsatzsteuer richtet sich danach, ob eine USt-IdNr. eingetragen ist
  (sonst: Kleinunternehmer nach § 19 UStG).
- **Noch nicht ausgefüllt.** Solange irgendwo eine eckige Klammer steht, gilt
  `Betreiber.istAusgefuellt` als falsch: die App zeigt einen Warnhinweis, und
  `tool/make_web.py` legt `docs/legal/` gar nicht erst an. Ein öffentliches
  Impressum mit „[DEIN VOLLER NAME]" wäre schlimmer als keins.
- **Die Texte sind Vorlagen, keine Rechtsberatung.** Vor einer
  Veröffentlichung gehören sie geprüft — besonders AGB und Widerruf, sobald
  wirklich verkauft wird.
- **Eigener kleiner Markdown-Leser** (`lib/ui/legal/markdown.dart`), weil ein
  ganzes Paket für vier Texte zu viel Gepäck wäre. Absätze werden
  zusammengezogen: die Umbrüche im Quelltext sitzen bei 80 Zeichen und haben in
  der Anzeige nichts verloren. Ein Rückstrich am Zeilenende hält einen Umbruch
  — so behalten Anschriften ihre Form. Dieselben Regeln stehen ein zweites Mal
  in `tool/make_web.py`; `legal_markdown_test.dart` und die Seiten in
  `docs/legal/` sind die Probe, dass beide Fassungen dasselbe tun.

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
│  │  ├─ screens/                  home_screen (Einstieg, in Blöcken),
│  │  │                            week_screen, levels_screen, game_screen samt
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
- **Töne:** `assets/sounds/` wird von `tool/`-freiem Python-Skript erzeugt
  (siehe Commit) — reine Sinus-Klänge, zusammen rund 134 KB. Beim Auflösen
  steigt die Tonhöhe mit der Combo über eine pentatonische Leiter; abschaltbar
  wie die Vibration.
  `SoundOutput` trennt das Abspielen vom Rest, damit Tests prüfen können,
  *welcher* Klang zu welchem Zug gehört, ohne etwas abzuspielen.
- Tempo und Stärke beider Animationen sind nach Gefühl gesetzt und in der
  Entwicklungsumgebung von niemandem gesehen worden. Sie gehören am Gerät
  nachjustiert: `flashDuration`, `popDuration` und die beiden Faktoren in
  `_clearFlash` und `_maybePop`.

`Size.fromHeight(x)` als `minimumSize` einer Schaltfläche bedeutet
*unendliche* Mindestbreite. Das sprengt jeden Knopf, der nicht in einer
breitenbegrenzten Spalte sitzt. Feste Mindestbreite verwenden.

Tests dürfen `AudioPlayer` nicht anlegen — ohne Plugin wirft das eine
Ausnahme, die kein `catchError` mehr auffängt. Deshalb überschreibt jeder Test
`soundOutputProvider` mit `RecordingOutput` aus `test/support/`.

Reine Dart-Tests, die Vibration auslösen, brauchen
`TestWidgetsFlutterBinding.ensureInitialized()` — sonst fehlt der
Plattformkanal.

Flutter sucht das Abwurfziel eines `Draggable` **an der Fingerposition**, nicht
dort, wo das gezogene Teil liegt (`drag_target.dart`, `hitTestInView`). Schwebt
das Teil versetzt über dem Finger, muss `feedbackOffset` den Trefferpunkt
mitziehen — sonst sind Ränder unerreichbar. Genau das war der Fall: die unterste
Brettreihe ließ sich mit keinem Teil belegen, weil der Finger dabei unter dem
Brett lag. Gesten-Tests gehören deshalb an die Ränder, nicht in die Mitte.

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

**Ton im Browser:** Safari und Chrome lassen Ton nur zu, wenn er das erste Mal
*während einer Berührung* startet. Deshalb bereitet `SoundOutput.unlock()` beim
allerersten Fingerdruck alle Klänge lautlos vor (`TessaApp`, `Listener`). Wer
erst beim ersten gelegten Teil anfängt, ist zu spät — dann bleibt es stumm.

**Vibration im Browser ist nicht möglich.** `HapticFeedback` läuft über einen
Plattformkanal, den es im Web nicht gibt; iOS-Safari kennt überhaupt keine
Vibrations-Schnittstelle. Die Einstellung ist dort abgeblendet und beschriftet.

Der Startbildschirm und die Statistik sind bewusst **keine `ListView`**: die
baut nur, was gerade sichtbar ist, und Tests fanden die unteren Einträge
nicht. Für eine kurze Seite
ist `SingleChildScrollView` + `Column` richtig — alles steht sofort im Baum,
auch für Vorlesefunktionen. Bei der Statistik ist genau das passiert: der neue
Eintrag „Rechtliches" schob den Schlusshinweis aus dem Sichtfeld, und ein
bestehender Test fand ihn nicht mehr.

`rootBundle` gehört nicht in einen Widget-Test: einen Anhang zu laden ist
echte Ein-/Ausgabe und kommt in der künstlichen Zeit eines Widget-Tests nie
zurück — der Test bleibt hängen, ohne Fehlermeldung. Tests, die die
ausgelieferten Rechtstexte prüfen, lesen sie deshalb über
`test/support/legal_vorlagen.dart` von der Platte. Es sind dieselben Dateien.

Widget-Tests mounten den Bildschirm, um den es geht, direkt in einer
`MaterialApp` — nicht `TessaApp`, deren Einstieg der Startbildschirm ist.
Nur `home_screen_test.dart` startet die ganze App.
