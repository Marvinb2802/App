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
export function loadSnapshot(athlete: Athlete): TrainingSnapshot {
  return buildSnapshot(athlete, listActivities(athlete.id, 1000));
}

/** Alles, was die Uebersichtsseite braucht - in einem Datenbankdurchlauf. */
export function loadDashboard(athlete: Athlete): {
  activities: Activity[];
  snapshot: TrainingSnapshot;
  series: FitnessPoint[];
} {
  const activities = listActivities(athlete.id, 1000);
  const refs = deriveReferences(athlete, activities);
  const scored = activities.map((activity) => scoreActivity(activity, refs));

  return {
    activities,
    snapshot: buildSnapshot(athlete, activities),
    series: fitnessSeries(scored),
  };
}
