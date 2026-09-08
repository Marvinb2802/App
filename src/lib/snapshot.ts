import {
  buildSnapshot,
  deriveReferences,
  fitnessSeries,
  scoreActivity,
  type FitnessPoint,
  type TrainingSnapshot,
} from "@/lib/metrics";
import { listActivities } from "@/lib/strava";
import type { Activity, Athlete } from "@/lib/types";

/** Laedt die Aktivitaeten eines Athleten und verdichtet sie zum Lagebild. */
export async function loadSnapshot(athlete: Athlete): Promise<TrainingSnapshot> {
  return buildSnapshot(athlete, await listActivities(athlete.id, 1000));
}

/** Alles, was die Uebersichtsseite braucht - in einem Datenbankdurchlauf. */
export async function loadDashboard(athlete: Athlete): Promise<{
  activities: Activity[];
  snapshot: TrainingSnapshot;
  series: FitnessPoint[];
}> {
  const activities = await listActivities(athlete.id, 1000);
  const refs = deriveReferences(athlete, activities);
  const scored = activities.map((activity) => scoreActivity(activity, refs));

  return {
    activities,
    snapshot: buildSnapshot(athlete, activities),
    series: fitnessSeries(scored),
  };
}
