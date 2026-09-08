import { redirect } from "next/navigation";
import { AnalysisPanel } from "@/components/AnalysisPanel";
import { isAiConfigured } from "@/lib/ai";
import { AnalysisSchema, type Analysis } from "@/lib/ai-schemas";
import { queryOne } from "@/lib/db";
import { getCurrentAthlete } from "@/lib/session";

export const dynamic = "force-dynamic";

export default async function AnalysePage() {
  const athlete = await getCurrentAthlete();
  if (!athlete) redirect("/");

  const row = await queryOne<{ payload: string; created_at: string }>(
    `SELECT payload, created_at FROM ai_reports
      WHERE athlete_id = $1 AND kind = 'analysis'
      ORDER BY id DESC LIMIT 1`,
    [athlete.id],
  );

  // Ein altes Ergebnis mit inzwischen geaendertem Schema darf die Seite nicht kippen.
  let initial: Analysis | null = null;
  if (row) {
    const parsed = AnalysisSchema.safeParse(JSON.parse(row.payload));
    if (parsed.success) initial = parsed.data;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">KI-Analyse</h1>
        <p className="mt-1 max-w-2xl text-sm text-ink-500">
          Claude bekommt dein verdichtetes Trainingsbild der letzten Monate – Belastungsverlauf,
          Wochenumfänge, Intensitätsverteilung, Ruhetage – und beurteilt es.
        </p>
      </div>

      <AnalysisPanel
        initial={initial}
        createdAt={row?.created_at ?? null}
        disabled={!isAiConfigured()}
      />
    </div>
  );
}
