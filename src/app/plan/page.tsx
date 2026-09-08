import { redirect } from "next/navigation";
import { PlanBuilder } from "@/components/PlanBuilder";
import { isAiConfigured } from "@/lib/ai";
import { PlanSchema, type TrainingPlan } from "@/lib/ai-schemas";
import { getDb } from "@/lib/db";
import { getCurrentAthlete } from "@/lib/session";
import { loadSnapshot } from "@/lib/snapshot";

export const dynamic = "force-dynamic";

/** Uebersetzt die haeufigste Strava-Sportart in die Auswahl des Formulars. */
function primarySportLabel(sport: string | undefined): string {
  if (!sport) return "Laufen";
  if (sport.includes("Ride")) return "Radfahren";
  if (sport === "Swim") return "Schwimmen";
  if (sport === "TrailRun") return "Trailrunning";
  return "Laufen";
}

export default async function PlanPage() {
  const athlete = await getCurrentAthlete();
  if (!athlete) redirect("/");

  const snapshot = loadSnapshot(athlete);

  const row = getDb()
    .prepare("SELECT payload FROM plans WHERE athlete_id = ? ORDER BY id DESC LIMIT 1")
    .get(athlete.id) as { payload: string } | undefined;

  let initial: TrainingPlan | null = null;
  if (row) {
    const parsed = PlanSchema.safeParse(JSON.parse(row.payload));
    if (parsed.success) initial = parsed.data;
  }

  // Vorbelegung aus dem tatsaechlichen Trainingsverhalten der letzten vier Wochen.
  const weeklySessions = Math.max(2, Math.round(snapshot.last28Days.sessions / 4));
  const weeklyHours = Math.max(1, Math.round((snapshot.last28Days.hours / 4) * 2) / 2);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Trainingsplan</h1>
        <p className="mt-1 max-w-2xl text-sm text-ink-500">
          Der Plan wird aus deiner echten Historie abgeleitet: aktuelle Fitness{" "}
          {Math.round(snapshot.fitness.ctl)}, zuletzt {snapshot.last28Days.sessions} Einheiten und{" "}
          {snapshot.last28Days.hours} Stunden in vier Wochen.
        </p>
      </div>

      <PlanBuilder
        initial={initial}
        disabled={!isAiConfigured()}
        defaults={{
          sessionsPerWeek: Math.min(12, weeklySessions),
          hoursPerWeek: Math.min(20, weeklyHours),
          primarySport: primarySportLabel(snapshot.sportSplit[0]?.sport),
          goal: athlete.goal ?? "",
        }}
      />
    </div>
  );
}
