import Link from "next/link";
import { ConnectPanel } from "@/components/ConnectPanel";
import { FitnessChart } from "@/components/FitnessChart";
import { SyncButton } from "@/components/SyncButton";
import { WeeklyVolume } from "@/components/WeeklyVolume";
import { Badge, Card, EmptyState, StatTile } from "@/components/ui";
import { isAiConfigured } from "@/lib/ai";
import { isDemoAthlete } from "@/lib/demo";
import { getCurrentAthlete } from "@/lib/session";
import { loadDashboard } from "@/lib/snapshot";
import { isStravaConfigured, lastSyncedAt } from "@/lib/strava";

export const dynamic = "force-dynamic";

const ERROR_TEXTS: Record<string, string> = {
  strava_nicht_konfiguriert:
    "STRAVA_CLIENT_ID und STRAVA_CLIENT_SECRET fehlen. Trage sie in .env.local ein.",
  zugriff_verweigert: "Du hast den Zugriff bei Strava abgelehnt.",
  kein_code: "Strava hat keinen Autorisierungscode zurückgegeben.",
  ungueltiger_state: "Sicherheitsprüfung fehlgeschlagen. Bitte erneut versuchen.",
  fehlende_berechtigung:
    "Die Berechtigung „Alle Aktivitäten“ wurde nicht erteilt. Ohne sie sieht die App deine Daten nicht.",
  kein_athlet: "Strava hat kein Athletenprofil geliefert.",
};

export default async function Dashboard({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; warnung?: string }>;
}) {
  const athlete = await getCurrentAthlete();
  const params = await searchParams;

  if (!athlete) {
    return <Landing error={params.error} />;
  }

  const { snapshot, series } = loadDashboard(athlete);
  const demo = isDemoAthlete(athlete.id);

  if (snapshot.activityCount === 0) {
    return (
      <div className="space-y-6">
        <PageHeader
          title={`Hallo ${athlete.firstname ?? "Athlet"}`}
          subtitle="Verbunden, aber noch ohne Daten."
        />
        <EmptyState title="Keine Aktivitäten gefunden">
          Synchronisiere deine Strava-Aktivitäten, damit die Auswertung starten kann.
          <div className="mt-4 flex justify-center">
            <SyncButton lastSyncedAt={lastSyncedAt(athlete.id)} />
          </div>
        </EmptyState>
      </div>
    );
  }

  const { fitness } = snapshot;
  const acwrTone = fitness.acwr > 1.5 ? "kritisch" : fitness.acwr > 1.3 ? "warnung" : "gut";

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <PageHeader
          title={`Hallo ${athlete.firstname ?? "Athlet"}`}
          subtitle={`${snapshot.activityCount} Aktivitäten ausgewertet · Stand ${snapshot.generatedAt.slice(0, 10)}`}
        />
        {!demo && <SyncButton lastSyncedAt={lastSyncedAt(athlete.id)} />}
      </div>

      {demo && (
        <p className="rounded-xl border border-ink-700 bg-ink-900/60 px-4 py-3 text-sm text-ink-300">
          <strong className="text-ink-100">Demo-Modus.</strong> Diese Trainingshistorie ist
          erzeugt, nicht aus Strava geladen. Analyse, Plan und Chat arbeiten trotzdem echt
          auf diesen Daten.
        </p>
      )}

      {params.warnung === "sync_unvollstaendig" && (
        <p className="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200">
          Die Verbindung steht, der erste Datenabgleich lief aber nicht durch. Starte ihn oben erneut.
        </p>
      )}

      {!isAiConfigured() && (
        <p className="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200">
          Ohne <code className="rounded bg-ink-900 px-1">ANTHROPIC_API_KEY</code> bleiben Analyse,
          Plan und Coach-Chat deaktiviert. Die Kennzahlen unten werden lokal berechnet und
          funktionieren auch so.
        </p>
      )}

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label="Fitness"
          value={Math.round(fitness.ctl)}
          hint={`${fitness.ctlRamp28d >= 0 ? "+" : ""}${fitness.ctlRamp28d} in 28 Tagen · ${fitness.trend}`}
          accent="#3987e5"
        />
        <StatTile
          label="Ermüdung"
          value={Math.round(fitness.atl)}
          hint="7-Tage-Mittel der Belastung"
          accent="#d95926"
        />
        <StatTile
          label="Form"
          value={Math.round(fitness.tsb)}
          hint={fitness.formState}
          accent="#199e70"
        />
        <StatTile
          label="Belastungsverhältnis"
          value={fitness.acwr.toFixed(2)}
          hint="7 Tage zu 28-Tage-Wochenmittel · 0,8–1,3 ist kontrolliert"
        />
      </div>

      <Card>
        <FitnessChart points={series} />
      </Card>

      <div className="grid items-start gap-6 lg:grid-cols-[3fr_2fr]">
        <Card>
          <WeeklyVolume weeks={snapshot.weeks} />
        </Card>

        <Card title="Letzte 4 Wochen" subtitle="im Vergleich zu den 4 Wochen davor">
          <dl className="space-y-3 text-sm">
            <Comparison label="Einheiten" now={snapshot.last28Days.sessions} before={snapshot.previous28Days.sessions} />
            <Comparison label="Stunden" now={snapshot.last28Days.hours} before={snapshot.previous28Days.hours} unit=" h" />
            <Comparison label="Distanz" now={snapshot.last28Days.distanceKm} before={snapshot.previous28Days.distanceKm} unit=" km" />
            <Comparison label="Höhenmeter" now={snapshot.last28Days.elevationM} before={snapshot.previous28Days.elevationM} unit=" hm" />
            <Comparison label="Belastung" now={snapshot.last28Days.load} before={snapshot.previous28Days.load} />
          </dl>

          <div className="mt-5 flex flex-wrap gap-2">
            <Badge tone={acwrTone}>Belastungssprung {fitness.acwr.toFixed(2)}</Badge>
            <Badge tone={snapshot.restDaysLast28 < 4 ? "warnung" : "gut"}>
              {snapshot.restDaysLast28} Ruhetage in 28 Tagen
            </Badge>
            <Badge tone={snapshot.intensityDistribution.easy < 70 ? "warnung" : "gut"}>
              {snapshot.intensityDistribution.easy}&nbsp;% locker
            </Badge>
          </div>

          <p className="mt-4 text-xs leading-relaxed text-ink-500">
            Intensitätsverteilung der letzten 90 Tage nach Zeit: {snapshot.intensityDistribution.easy}&nbsp;%
            locker, {snapshot.intensityDistribution.moderate}&nbsp;% mittel,{" "}
            {snapshot.intensityDistribution.hard}&nbsp;% hart.
          </p>
        </Card>
      </div>

      <div className="grid items-start gap-6 lg:grid-cols-2">
        <Card title="Sportarten" subtitle="Anteil an der Trainingszeit, letzte 90 Tage">
          <ul className="space-y-2.5">
            {snapshot.sportSplit.map((entry) => (
              <li key={entry.sport} className="text-sm">
                <div className="flex items-baseline justify-between gap-3">
                  <span className="text-ink-100">{entry.sport}</span>
                  <span className="tabular-nums text-ink-500">
                    {entry.hours} h · {entry.sessions}×
                  </span>
                </div>
                <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-ink-800">
                  <div className="h-full rounded-full bg-fitness" style={{ width: `${entry.share}%` }} />
                </div>
              </li>
            ))}
          </ul>
        </Card>

        <Card
          title="Letzte Einheiten"
          action={
            <Link href="/analyse" className="text-sm text-brand-light hover:underline">
              KI-Analyse öffnen →
            </Link>
          }
        >
          <ul className="divide-y divide-ink-800 text-sm">
            {snapshot.recentActivities.slice(0, 8).map((activity, index) => (
              <li key={`${activity.date}-${index}`} className="flex items-baseline justify-between gap-3 py-2.5">
                <div className="min-w-0">
                  <p className="truncate text-ink-100">{activity.name}</p>
                  <p className="text-xs text-ink-500">
                    {activity.date} · {activity.sport} · {activity.durationMin} min
                    {activity.distanceKm > 0 && ` · ${activity.distanceKm} km`}
                    {activity.avgHr && ` · ${activity.avgHr} bpm`}
                    {activity.avgPace && ` · ${activity.avgPace}`}
                  </p>
                </div>
                <span className="shrink-0 tabular-nums text-ink-300">{activity.load}</span>
              </li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-ink-500">Rechte Spalte: Belastungspunkte der Einheit.</p>
        </Card>
      </div>

      {snapshot.references.estimated.length > 0 && (
        <Card title="Geschätzte Referenzwerte" subtitle="Diese Werte machen die Berechnung ungenauer">
          <ul className="list-inside list-disc space-y-1 text-sm text-ink-300">
            {snapshot.references.estimated.map((note) => (
              <li key={note}>{note}</li>
            ))}
          </ul>
          <Link
            href="/einstellungen"
            className="mt-4 inline-block text-sm text-brand-light hover:underline"
          >
            Echte Werte hinterlegen →
          </Link>
        </Card>
      )}
    </div>
  );
}

function PageHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      <p className="mt-1 text-sm text-ink-500">{subtitle}</p>
    </div>
  );
}

function Comparison({
  label,
  now,
  before,
  unit = "",
}: {
  label: string;
  now: number;
  before: number;
  unit?: string;
}) {
  const delta = before > 0 ? Math.round(((now - before) / before) * 100) : null;

  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-ink-800 pb-2 last:border-0">
      <dt className="text-ink-300">{label}</dt>
      <dd className="flex items-baseline gap-2 tabular-nums">
        <span className="text-ink-100">
          {now}
          {unit}
        </span>
        {delta !== null && (
          <span className={delta >= 0 ? "text-xs text-emerald-400" : "text-xs text-amber-400"}>
            {delta >= 0 ? "+" : ""}
            {delta}&nbsp;%
          </span>
        )}
      </dd>
    </div>
  );
}

function Landing({ error }: { error?: string }) {
  return (
    <div className="mx-auto max-w-3xl py-10">
      <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
        Du trainierst.
        <br />
        <span className="text-brand-light">Pacer sagt dir, was es bringt.</span>
      </h1>

      <p className="mt-5 max-w-xl text-lg leading-relaxed text-ink-300">
        Pacer berechnet aus deinen Einheiten Fitness, Ermüdung und Form – dieselben Kennzahlen,
        mit denen Trainer arbeiten. Eine KI liest daraus, was gerade gut läuft und was dich
        bremst, und schreibt dir einen Trainingsplan, der zu deinem echten Niveau passt.
        Deine Aktivitäten holt sich Pacer aus Strava.
      </p>

      {error && (
        <p className="mt-6 rounded-xl border border-red-800/60 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          {ERROR_TEXTS[error] ?? `Fehler: ${error}`}
        </p>
      )}

      <div className="mt-8">
        <ConnectPanel stravaConfigured={isStravaConfigured()} />
      </div>

      <div className="mt-14 grid gap-5 sm:grid-cols-2">
        <Feature title="Belastung statt Bauchgefühl">
          Jede Einheit wird nach Leistung, Herzfrequenz oder Tempo bewertet. Daraus entstehen
          Fitness (42-Tage-Mittel), Ermüdung (7-Tage-Mittel) und Form – dieselben Kennzahlen,
          mit denen Trainer arbeiten.
        </Feature>
        <Feature title="Analyse, die Zahlen nennt">
          Die KI bekommt dein verdichtetes Trainingsbild und begründet jede Aussage mit dem
          Wert, auf dem sie beruht. Fehlen Daten, sagt sie das, statt zu raten.
        </Feature>
        <Feature title="Plan auf deinem Niveau">
          Der Trainingsplan setzt bei deinem tatsächlichen Wochenumfang an, steigert um
          höchstens 5–10 Prozent pro Woche und plant Entlastungswochen ein.
        </Feature>
        <Feature title="Coach zum Nachfragen">
          Im Chat kannst du nachhaken – „Warum bin ich müde?“, „Reicht ein Tag Pause?“ – und
          bekommst Antworten, die deine letzten Wochen kennen.
        </Feature>
      </div>
    </div>
  );
}

function Feature({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-ink-800 bg-ink-850/50 p-5">
      <h3 className="font-medium text-ink-100">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-ink-300">{children}</p>
    </div>
  );
}
