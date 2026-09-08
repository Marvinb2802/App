import { redirect } from "next/navigation";
import { SettingsForm } from "@/components/SettingsForm";
import { Card } from "@/components/ui";
import { isDemoAthlete } from "@/lib/demo";
import { getCurrentAthlete } from "@/lib/session";
import { loadSnapshot } from "@/lib/snapshot";

export const dynamic = "force-dynamic";

export default async function SettingsPage() {
  const athlete = await getCurrentAthlete();
  if (!athlete) redirect("/");

  const snapshot = loadSnapshot(athlete);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Einstellungen</h1>
        <p className="mt-1 max-w-2xl text-sm text-ink-500">
          {isDemoAthlete(athlete.id)
            ? "Demo-Athlet. Änderungen wirken sofort auf die Auswertung, betreffen aber keinen echten Strava-Account."
            : "Verbunden mit Strava. Diese Werte bleiben lokal in deiner Datenbank."}
        </p>
      </div>

      <SettingsForm athlete={athlete} />

      <Card title="Datengrundlage" subtitle="Woraus die App ihre Belastungswerte zieht">
        <dl className="grid gap-4 text-sm sm:grid-cols-2">
          <Row term="Aktivitäten in der Datenbank">{snapshot.activityCount}</Row>
          <Row term="Einheiten mit Herzfrequenz (90 Tage)">
            {snapshot.dataQuality.heartrateCoverage}&nbsp;%
          </Row>
          <Row term="Einheiten mit Leistungsmessung (90 Tage)">
            {snapshot.dataQuality.powerCoverage}&nbsp;%
          </Row>
          <Row term="Belastung berechnet aus">
            {Object.entries(snapshot.dataQuality.loadSources)
              .filter(([, count]) => count > 0)
              .map(([source, count]) => `${SOURCE_LABEL[source] ?? source}: ${count}`)
              .join(" · ") || "keine Daten"}
          </Row>
        </dl>

        {snapshot.references.estimated.length > 0 && (
          <ul className="mt-5 list-inside list-disc space-y-1 border-t border-ink-800 pt-4 text-sm text-ink-500">
            {snapshot.references.estimated.map((note) => (
              <li key={note}>{note}</li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}

const SOURCE_LABEL: Record<string, string> = {
  power: "Leistung",
  heartrate: "Herzfrequenz",
  pace: "Tempo",
  duration: "nur Dauer",
};

function Row({ term, children }: { term: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-3 border-b border-ink-800 pb-2">
      <dt className="text-ink-300">{term}</dt>
      <dd className="tabular-nums text-ink-100">{children}</dd>
    </div>
  );
}
