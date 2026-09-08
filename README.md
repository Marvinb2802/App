# Pacer

Pacer wertet dein Ausdauertraining sportwissenschaftlich aus, erklärt dir mit Claude
deine Form und schreibt dir einen Trainingsplan, der zu deinem tatsächlichen Niveau
passt. Die Aktivitäten kommen aus Strava, gespeichert wird in Postgres.

> Pacer ist ein eigenständiges Angebot und gehört nicht zu Strava. Strava ist
> ausschließlich Datenquelle. Wer die App öffentlich betreibt, muss die
> [Strava-Markenrichtlinien](https://developers.strava.com/guidelines/) einhalten —
> unter anderem den Hinweis „powered by Strava" (steht im Footer) und den offiziellen
> „Connect with Strava"-Button.

## Was die App macht

**Kennzahlen — lokal berechnet, ohne KI.**
Jede Aktivität bekommt eine Trainingsbelastung in TSS-ähnlichen Punkten (eine Stunde an
der anaeroben Schwelle = 100). Die Berechnung nutzt die beste verfügbare Datenquelle:

1. Leistungsmesser (Rad, mit FTP) → `Stunden × IF² × 100`
2. Herzfrequenz (mit Schwellen-HF) → hrTSS
3. Tempo (Laufen, mit Schwellentempo) → rTSS
4. Nur Dauer → sportartspezifischer Erfahrungswert

Daraus entstehen nach dem Impulse-Response-Modell:

| Kennzahl | Bedeutung |
|---|---|
| **Fitness** (CTL) | 42-Tage-Mittel der Tagesbelastung |
| **Ermüdung** (ATL) | 7-Tage-Mittel der Tagesbelastung |
| **Form** (TSB) | Fitness minus Ermüdung |
| **Belastungsverhältnis** (ACWR) | 7-Tage-Belastung zum 28-Tage-Wochenmittel; 0,8–1,3 gilt als kontrolliert |
| **Monotonie / Strain** | nach Foster, pro Woche |

Dazu Wochenumfänge, Intensitätsverteilung (locker / mittel / hart), Ruhetage und
Sportartenverteilung.

**KI-Funktionen — mit Claude Opus 5.**

- **Analyse** (`/analyse`): Claude bekommt das verdichtete Trainingsbild und beurteilt
  Form, Belastungsentwicklung, Intensitätsverteilung, Regeneration und Konsistenz —
  mit Stärken, Risiken (nach Schweregrad) und priorisierten Empfehlungen.
- **Trainingsplan** (`/plan`): 2–20 Wochen, Tag für Tag, ausgehend von deinem
  *tatsächlichen* Ausgangsniveau, mit Entlastungswochen und Tapering.
- **Coach-Chat** (`/coach`): Rückfragen im Dialog, Antworten werden gestreamt.

Beide strukturierten Antworten laufen über erzwungene JSON-Schemata, damit die
Oberfläche sie zuverlässig darstellen kann.

## Schnellstart

```bash
npm install
cp .env.example .env.local     # und ausfüllen, siehe unten
npm run dev                    # http://localhost:3000
```

Pflicht sind nur zwei Werte: `DATABASE_URL` und `SESSION_SECRET`. Eine kostenlose
Postgres-Datenbank gibt es in zwei Minuten bei [Neon](https://neon.tech) oder
[Supabase](https://supabase.com) — die Verbindungszeichenkette von dort kopieren und
eintragen. Die Tabellen legt Pacer beim ersten Aufruf selbst an.

Auf der Startseite gibt es dann **„Mit Demo-Daten ansehen"** — damit läuft die komplette
App inklusive Kennzahlen ohne Strava-Account und ohne API-Key.

## Konfiguration (`.env.local`)

| Variable | Pflicht | Wofür |
|---|---|---|
| `DATABASE_URL` | **ja** | Postgres-Verbindung, z. B. von Neon oder Supabase |
| `SESSION_SECRET` | **ja** (Produktion) | `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |
| `APP_URL` | ja | Basis-URL, lokal `http://localhost:3000` |
| `STRAVA_CLIENT_ID` | für Strava | aus den [Strava-API-Einstellungen](https://www.strava.com/settings/api) |
| `STRAVA_CLIENT_SECRET` | für Strava | ebenda |
| `ANTHROPIC_API_KEY` | für die KI | aus der [Anthropic Console](https://console.anthropic.com/settings/keys) |

Ohne `ANTHROPIC_API_KEY` funktionieren alle lokal berechneten Kennzahlen; nur Analyse,
Plan und Chat sind deaktiviert und weisen darauf hin.

### Strava-App einrichten

1. Unter <https://www.strava.com/settings/api> eine Anwendung anlegen.
2. **Authorization Callback Domain** auf `localhost` setzen (für die lokale Entwicklung).
3. Client-ID und Client-Secret in `.env.local` eintragen.

Die App fragt die Berechtigungen `read`, `activity:read_all` und `profile:read_all` an.
Ohne `activity:read_all` bleiben private Aktivitäten unsichtbar; die App bricht den
Login in dem Fall mit einem Hinweis ab.

## Genauigkeit verbessern

Unter `/einstellungen` lassen sich Maximal- und Schwellenherzfrequenz, FTP,
Schwellentempo und Gewicht hinterlegen. Fehlen sie, schätzt die App:

- Maximal-HF aus der höchsten je gemessenen Herzfrequenz
- Schwellen-HF als 90 % der Maximal-HF (oder aus den Strava-Zonen)
- Schwellentempo aus dem 95. Perzentil der längeren Läufe

Jede Schätzung wird in der Oberfläche und im Prompt an die KI ausgewiesen — die
Analyse weiß also, wo sie auf Annahmen steht.

## Architektur

```
src/
  app/
    page.tsx                  Übersicht mit Kennzahlen und Diagrammen
    analyse/ plan/ coach/ einstellungen/
    api/
      auth/strava/            OAuth-Start und Callback (state-geschützt)
      auth/demo/ logout/
      strava/sync/            Aktivitäten nachladen
      ai/analysis/ plan/ chat/
  lib/
    db.ts                     Postgres-Pool, Abfragehelfer und Schema
    session.ts                HMAC-signiertes Session-Cookie
    strava.ts                 OAuth, Token-Refresh, Sync
    metrics.ts                Belastung, CTL/ATL/TSB, Wochen, Lagebild
    ai.ts                     Prompts und Claude-Aufrufe
    ai-schemas.ts             Zod-Schemata der strukturierten Antworten
    demo.ts                   erzeugte Trainingshistorie
  components/                 Oberfläche, Diagramme als Inline-SVG
```

**Technik:** Next.js 15 (App Router), React 19, TypeScript, Tailwind CSS 4,
Postgres über `pg`, `@anthropic-ai/sdk`, Zod.

Die Diagrammfarben (Blau / Orange / Grün) sind gegen die dunkle Diagrammfläche auf
Helligkeitsband, Sättigung, Kontrast und Unterscheidbarkeit bei Farbsehschwäche
geprüft; der Wochenumfang lässt sich zusätzlich als Tabelle anzeigen.

## Online stellen

Pacer läuft auf jeder Plattform, die Next.js ausführt. Der übliche Weg:

1. **Datenbank anlegen** — bei [Neon](https://neon.tech) ein Projekt erstellen und die
   Verbindungszeichenkette kopieren (die mit `?sslmode=require`).
2. **Bei [Vercel](https://vercel.com) einloggen** und dieses GitHub-Repository importieren.
3. **Umgebungsvariablen setzen** (Settings → Environment Variables):
   `DATABASE_URL`, `SESSION_SECRET`, `APP_URL` (die Vercel-Adresse), dazu
   `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET` und `ANTHROPIC_API_KEY`.
4. **Strava anpassen** — in den Strava-API-Einstellungen die „Authorization Callback
   Domain" auf die Vercel-Domain umstellen (ohne `https://`).
5. Deployen. Die Tabellen legt Pacer beim ersten Aufruf selbst an.

Zwei Grenzen der kostenlosen Vercel-Stufe:

- **Zeitlimit 60 Sekunden.** Analyse und Chat passen bequem hinein, ein Trainingsplan
  über viele Wochen nicht immer. Der Wert steht als `maxDuration` in
  `src/app/api/ai/plan/route.ts` und lässt sich auf einem bezahlten Plan auf 300 erhöhen.
- **Nur für private Projekte.** Sobald Geld fließt, verlangt Vercel den bezahlten Plan.

## Befehle

```bash
npm run dev        # Entwicklungsserver
npm run build      # Produktionsbuild
npm run start      # Produktionsserver
npm run typecheck  # TypeScript prüfen
```

## Grenzen

- Die Auswertung nutzt Aktivitäts-Zusammenfassungen, keine Sekunden-Streams. Die
  Intensität einer Einheit wird darum aus Durchschnittswerten abgeleitet — eine
  Intervalleinheit erscheint dadurch moderater, als sie sich angefühlt hat.
- Strava begrenzt auf 100 Anfragen je 15 Minuten und 1000 pro Tag. Der Sync holt
  standardmäßig die letzten 365 Tage in Seiten zu 200 Aktivitäten.
- Ein Trainingsplan über viele Wochen kann ein bis drei Minuten dauern. Bei einem
  Deployment mit kurzem Funktions-Timeout (z. B. Vercel Hobby) ist der Wert in
  `src/app/api/ai/plan/route.ts` (`maxDuration`) entsprechend zu prüfen.
- SQLite und der lokale Dateipfad setzen einen Server mit beschreibbarem Dateisystem
  voraus. Für eine serverlose Umgebung muss die Datenhaltung getauscht werden.

## Sicherheit und Verantwortung

Tokens und Trainingsdaten liegen ausschließlich in der lokalen SQLite-Datei; das
Session-Cookie ist `httpOnly` und HMAC-signiert, der OAuth-Flow gegen CSRF mit einem
`state`-Wert abgesichert. `data/*.db` ist von der Versionskontrolle ausgenommen.

Die App gibt Trainingsempfehlungen, keine medizinischen Ratschläge. Bei Schmerzen,
anhaltender Erschöpfung oder Krankheit entscheidet eine Ärztin oder ein Arzt.
