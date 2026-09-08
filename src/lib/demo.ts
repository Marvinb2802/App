import { getDb } from "@/lib/db";
import { storeActivities, type SummaryActivity } from "@/lib/strava";

/**
 * Demo-Athlet mit erzeugter Trainingshistorie. Er erlaubt es, die Auswertung und
 * die Planung auszuprobieren, ohne einen Strava-Account zu verbinden.
 * Die negative ID kann nicht mit einer echten Strava-Athleten-ID kollidieren.
 */
export const DEMO_ATHLETE_ID = -1;

/** Deterministischer Zufall, damit die Demo bei jedem Aufruf gleich aussieht. */
function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

type Session = {
  sport: "Run" | "Ride";
  minutes: number;
  /** relative Intensitaet, 1.0 = Schwelle */
  intensity: number;
  name: string;
};

/** Ein typischer Wochenaufbau eines ambitionierten Laeufers mit Radeinheiten. */
function weekTemplate(weekIndex: number, isRecovery: boolean, random: () => number): Session[] {
  const volumeFactor = (isRecovery ? 0.65 : 1) * (0.9 + weekIndex * 0.008);

  const sessions: Session[] = [
    { sport: "Run", minutes: 45, intensity: 0.72, name: "Lockerer Dauerlauf" },
    { sport: "Run", minutes: 55, intensity: 0.95, name: "Intervalle 6x800 m" },
    { sport: "Ride", minutes: 75, intensity: 0.7, name: "Grundlagenfahrt" },
    { sport: "Run", minutes: 50, intensity: 0.74, name: "Ruhiger Dauerlauf" },
    { sport: "Run", minutes: 40, intensity: 0.88, name: "Tempodauerlauf" },
    { sport: "Run", minutes: 85, intensity: 0.7, name: "Longrun" },
  ];

  if (isRecovery) sessions.splice(1, 1); // Intervalle raus in der Entlastungswoche

  return sessions.map((session) => ({
    ...session,
    minutes: Math.round(session.minutes * volumeFactor * (0.92 + random() * 0.16)),
    intensity: session.intensity * (0.97 + random() * 0.06),
  }));
}

/** Schwellenherzfrequenz des Demo-Athleten - Bezugsgroesse fuer die HF-Kurve. */
const DEMO_THRESHOLD_HR = 172;

/**
 * Durchschnittliche Herzfrequenz einer Einheit. Sie folgt nicht linear dem Tempo:
 * ein lockerer Dauerlauf liegt bei rund 80 Prozent der Schwellen-HF, ein
 * Tempolauf bei etwa 91, eine Intervalleinheit im Mittel bei 95 Prozent.
 */
function heartRateFor(intensity: number): number {
  return DEMO_THRESHOLD_HR * (0.4 + 0.58 * intensity);
}

function speedFor(sport: "Run" | "Ride", intensity: number): number {
  // Schwellentempo: 3:55 min/km laufen (4.25 m/s), 34 km/h Rad (9.4 m/s)
  const threshold = sport === "Run" ? 4.25 : 9.4;
  return threshold * (0.62 + intensity * 0.38);
}

export function seedDemoData(): void {
  const db = getDb();

  db.prepare(
    `INSERT INTO athletes (id, firstname, lastname, city, country, sex, weight_kg, max_hr, threshold_hr, goal)
     VALUES (@id, 'Demo', 'Athlet', 'Freiburg', 'Deutschland', 'M', 72, 191, 172,
             'Halbmarathon unter 1:30 h')
     ON CONFLICT(id) DO UPDATE SET updated_at = datetime('now')`,
  ).run({ id: DEMO_ATHLETE_ID });

  const alreadySeeded = db
    .prepare("SELECT COUNT(*) AS count FROM activities WHERE athlete_id = ?")
    .get(DEMO_ATHLETE_ID) as { count: number };
  if (alreadySeeded.count > 0) return;

  const random = seededRandom(20260908);
  const weeks = 30;
  const activities: SummaryActivity[] = [];
  let id = -1;

  for (let week = 0; week < weeks; week++) {
    // Krankheitswoche: eine laengere Pause macht die Analyse realistisch.
    if (week === 18) continue;

    const isRecovery = week % 4 === 3;
    const sessions = weekTemplate(week, isRecovery, random);
    const weekdaySlots = [0, 1, 2, 3, 5, 6]; // Freitag bleibt Ruhetag

    sessions.forEach((session, index) => {
      const daysAgo = (weeks - 1 - week) * 7 + (6 - weekdaySlots[index % weekdaySlots.length]);
      const start = new Date();
      start.setDate(start.getDate() - daysAgo);
      start.setHours(7 + Math.floor(random() * 3), Math.floor(random() * 60), 0, 0);

      const seconds = session.minutes * 60;
      const speed = speedFor(session.sport, session.intensity);
      const averageHeartrate = Math.round(heartRateFor(session.intensity) + random() * 4);

      activities.push({
        id: id--,
        name: session.name,
        sport_type: session.sport,
        start_date: start.toISOString(),
        start_date_local: start.toISOString(),
        distance: Math.round(speed * seconds),
        moving_time: seconds,
        elapsed_time: seconds + Math.round(random() * 120),
        total_elevation_gain: Math.round(
          (session.sport === "Ride" ? 12 : 8) * (session.minutes / 10) * (0.5 + random()),
        ),
        average_speed: Number(speed.toFixed(3)),
        max_speed: Number((speed * 1.3).toFixed(3)),
        average_heartrate: averageHeartrate,
        max_heartrate: Math.round(averageHeartrate + 12 + random() * 12),
        average_watts: session.sport === "Ride" ? Math.round(150 + session.intensity * 120) : null,
        weighted_average_watts:
          session.sport === "Ride" ? Math.round(160 + session.intensity * 125) : null,
        kilojoules: session.sport === "Ride" ? Math.round(session.minutes * 12) : null,
        average_cadence: session.sport === "Run" ? 84 + Math.round(random() * 5) : 88,
        suffer_score: null,
        has_heartrate: true,
        trainer: false,
      });
    });
  }

  storeActivities(DEMO_ATHLETE_ID, activities);

  db.prepare(
    `INSERT INTO sync_state (athlete_id, last_synced_at) VALUES (?, datetime('now'))
     ON CONFLICT(athlete_id) DO UPDATE SET last_synced_at = datetime('now')`,
  ).run(DEMO_ATHLETE_ID);
}

export function isDemoAthlete(athleteId: number): boolean {
  return athleteId === DEMO_ATHLETE_ID;
}
