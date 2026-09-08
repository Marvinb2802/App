import type { Activity, Athlete } from "@/lib/types";

/* -------------------------------------------------------------------------- */
/* Hilfsfunktionen                                                            */
/* -------------------------------------------------------------------------- */

const DAY_MS = 24 * 60 * 60 * 1000;

export function toDayKey(iso: string): string {
  return iso.slice(0, 10);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function round(value: number, digits = 1): number {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((sum, v) => sum + v, 0) / values.length;
}

function stdDev(values: number[]): number {
  if (values.length < 2) return 0;
  const m = mean(values);
  return Math.sqrt(mean(values.map((v) => (v - m) ** 2)));
}

function percentile(values: number[], p: number): number | null {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const index = clamp(Math.round((p / 100) * (sorted.length - 1)), 0, sorted.length - 1);
  return sorted[index];
}

/** Montag der Woche, in der `date` liegt (lokale Zeit, ISO-Wochenlogik). */
export function weekStart(date: Date): Date {
  const copy = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const weekday = (copy.getDay() + 6) % 7; // Montag = 0
  copy.setDate(copy.getDate() - weekday);
  return copy;
}

/* -------------------------------------------------------------------------- */
/* Sportarten                                                                 */
/* -------------------------------------------------------------------------- */

const ENDURANCE_SPORTS = new Set([
  "Run", "TrailRun", "VirtualRun", "Ride", "VirtualRide", "GravelRide",
  "MountainBikeRide", "EBikeRide", "Swim", "Rowing", "NordicSki",
  "BackcountrySki", "Hike", "Walk", "Elliptical", "StairStepper",
]);

/** Grundbelastung pro Stunde, wenn weder Leistung noch Herzfrequenz vorliegen. */
const BASE_LOAD_PER_HOUR: Record<string, number> = {
  Run: 80, TrailRun: 85, VirtualRun: 75,
  Ride: 60, VirtualRide: 65, GravelRide: 65, MountainBikeRide: 70, EBikeRide: 30,
  Swim: 70, Rowing: 70, NordicSki: 75,
  Hike: 40, Walk: 25, WeightTraining: 45, Workout: 50, Yoga: 20, Crossfit: 60,
};

export function isEndurance(sportType: string | null): boolean {
  return sportType !== null && ENDURANCE_SPORTS.has(sportType);
}

export function isRun(sportType: string | null): boolean {
  return sportType === "Run" || sportType === "TrailRun" || sportType === "VirtualRun";
}

export function isRide(sportType: string | null): boolean {
  return (
    sportType === "Ride" || sportType === "VirtualRide" ||
    sportType === "GravelRide" || sportType === "MountainBikeRide"
  );
}

/* -------------------------------------------------------------------------- */
/* Trainingsbelastung pro Aktivitaet                                          */
/* -------------------------------------------------------------------------- */

export type LoadSource = "power" | "heartrate" | "pace" | "duration";

export type ScoredActivity = {
  activity: Activity;
  /** Trainingsbelastung in TSS-aehnlichen Punkten (1 h an der Schwelle = 100). */
  load: number;
  /** Intensitaetsfaktor relativ zur Schwelle (1.0 = Schwellentempo/-leistung). */
  intensity: number;
  source: LoadSource;
  hours: number;
};

/**
 * Referenzwerte des Athleten. Fehlt etwas in den Stammdaten, wird es aus den
 * vorhandenen Aktivitaeten geschaetzt (z. B. Schwellen-HF aus der Maximal-HF).
 */
export type AthleteReferences = {
  thresholdHr: number | null;
  maxHr: number | null;
  ftp: number | null;
  /** Schwellentempo Laufen in m/s */
  thresholdRunSpeed: number | null;
  estimated: string[];
};

export function deriveReferences(
  athlete: Pick<Athlete, "threshold_hr" | "max_hr" | "ftp" | "threshold_pace">,
  activities: Activity[],
): AthleteReferences {
  const estimated: string[] = [];

  let maxHr = athlete.max_hr;
  if (!maxHr) {
    const observed = activities
      .map((a) => a.max_heartrate)
      .filter((v): v is number => typeof v === "number" && v > 100);
    const peak = observed.length > 0 ? Math.max(...observed) : null;
    if (peak) {
      maxHr = Math.round(peak);
      estimated.push("Maximalherzfrequenz aus der hoechsten gemessenen HF abgeleitet");
    }
  }

  let thresholdHr = athlete.threshold_hr;
  if (!thresholdHr && maxHr) {
    thresholdHr = Math.round(maxHr * 0.9);
    estimated.push("Schwellenherzfrequenz als 90 % der Maximal-HF geschaetzt");
  }

  let thresholdRunSpeed = athlete.threshold_pace;
  if (!thresholdRunSpeed) {
    // Naeherung: 95. Perzentil der Durchschnittsgeschwindigkeit laengerer Laeufe.
    const speeds = activities
      .filter((a) => isRun(a.sport_type) && (a.moving_time ?? 0) >= 20 * 60)
      .map((a) => a.average_speed)
      .filter((v): v is number => typeof v === "number" && v > 1);
    const p95 = percentile(speeds, 95);
    if (p95) {
      thresholdRunSpeed = round(p95 * 0.98, 3);
      estimated.push("Schwellentempo Laufen aus den schnellsten Laeufen geschaetzt");
    }
  }

  return { thresholdHr, maxHr, ftp: athlete.ftp, thresholdRunSpeed, estimated };
}

/**
 * Belastung einer Einzeleinheit. Die Reihenfolge folgt der Datenqualitaet:
 * Leistungsmesser > Herzfrequenz > Tempo > reine Dauer.
 */
export function scoreActivity(activity: Activity, refs: AthleteReferences): ScoredActivity {
  const seconds = activity.moving_time ?? activity.elapsed_time ?? 0;
  const hours = seconds / 3600;

  if (hours <= 0) {
    return { activity, load: 0, intensity: 0, source: "duration", hours: 0 };
  }

  // 1. Leistungsbasiert (Rad mit FTP)
  const normalizedPower = activity.weighted_average_watts ?? activity.average_watts;
  if (isRide(activity.sport_type) && refs.ftp && normalizedPower) {
    const intensity = clamp(normalizedPower / refs.ftp, 0.3, 1.5);
    return {
      activity,
      load: round(hours * intensity ** 2 * 100),
      intensity: round(intensity, 2),
      source: "power",
      hours: round(hours, 2),
    };
  }

  // 2. Herzfrequenzbasiert (hrTSS)
  if (refs.thresholdHr && activity.average_heartrate && activity.average_heartrate > 60) {
    const intensity = clamp(activity.average_heartrate / refs.thresholdHr, 0.4, 1.2);
    return {
      activity,
      load: round(hours * intensity ** 2 * 100),
      intensity: round(intensity, 2),
      source: "heartrate",
      hours: round(hours, 2),
    };
  }

  // 3. Tempobasiert (Laufen mit geschaetztem Schwellentempo)
  if (isRun(activity.sport_type) && refs.thresholdRunSpeed && activity.average_speed) {
    const intensity = clamp(activity.average_speed / refs.thresholdRunSpeed, 0.4, 1.3);
    return {
      activity,
      load: round(hours * intensity ** 2 * 100),
      intensity: round(intensity, 2),
      source: "pace",
      hours: round(hours, 2),
    };
  }

  // 4. Fallback: Dauer x sportartspezifischer Erfahrungswert
  const base = BASE_LOAD_PER_HOUR[activity.sport_type ?? ""] ?? 50;
  return {
    activity,
    load: round(hours * base),
    intensity: round(Math.sqrt(base / 100), 2),
    source: "duration",
    hours: round(hours, 2),
  };
}

/* -------------------------------------------------------------------------- */
/* Fitness / Ermuedung / Form                                                 */
/* -------------------------------------------------------------------------- */

export type FitnessPoint = {
  date: string;
  load: number;
  /** Chronische Belastung, 42-Tage-Mittel: "Fitness" */
  ctl: number;
  /** Akute Belastung, 7-Tage-Mittel: "Ermuedung" */
  atl: number;
  /** Form / Frische: Fitness minus Ermuedung des Vortags */
  tsb: number;
};

const CTL_DAYS = 42;
const ATL_DAYS = 7;

/**
 * Impulse-Response-Modell nach Banister: exponentiell geglaettete Tagesbelastung.
 * Die Reihe laeuft lueckenlos vom ersten Trainingstag bis heute.
 */
export function fitnessSeries(scored: ScoredActivity[]): FitnessPoint[] {
  if (scored.length === 0) return [];

  const dailyLoad = new Map<string, number>();
  for (const item of scored) {
    const key = toDayKey(item.activity.start_date_local ?? item.activity.start_date);
    dailyLoad.set(key, (dailyLoad.get(key) ?? 0) + item.load);
  }

  const days = [...dailyLoad.keys()].sort();
  const first = new Date(`${days[0]}T00:00:00Z`);
  const today = new Date(`${toDayKey(new Date().toISOString())}T00:00:00Z`);

  const series: FitnessPoint[] = [];
  let ctl = 0;
  let atl = 0;

  for (let t = first.getTime(); t <= today.getTime(); t += DAY_MS) {
    const key = toDayKey(new Date(t).toISOString());
    const load = dailyLoad.get(key) ?? 0;

    // Form ist die Bilanz von gestern - vor dem Training des heutigen Tages.
    const tsb = ctl - atl;
    ctl += (load - ctl) / CTL_DAYS;
    atl += (load - atl) / ATL_DAYS;

    series.push({
      date: key,
      load: round(load),
      ctl: round(ctl),
      atl: round(atl),
      tsb: round(tsb),
    });
  }

  return series;
}

/* -------------------------------------------------------------------------- */
/* Wochenaggregate                                                            */
/* -------------------------------------------------------------------------- */

export type WeekSummary = {
  /** Montag der Woche, ISO-Datum */
  weekStart: string;
  sessions: number;
  hours: number;
  distanceKm: number;
  elevationM: number;
  load: number;
  /** Foster-Monotonie: Mittelwert / Streuung der Tagesbelastung */
  monotony: number;
  /** Foster-Strain: Wochenbelastung x Monotonie */
  strain: number;
  sports: Record<string, number>;
};

export function weeklySummaries(scored: ScoredActivity[], weeks = 16): WeekSummary[] {
  const buckets = new Map<string, ScoredActivity[]>();

  for (const item of scored) {
    const date = new Date(item.activity.start_date_local ?? item.activity.start_date);
    const key = toDayKey(weekStart(date).toISOString());
    const list = buckets.get(key);
    if (list) list.push(item);
    else buckets.set(key, [item]);
  }

  const currentWeek = weekStart(new Date());
  const result: WeekSummary[] = [];

  for (let i = weeks - 1; i >= 0; i--) {
    const start = new Date(currentWeek);
    start.setDate(start.getDate() - i * 7);
    const key = toDayKey(start.toISOString());
    const items = buckets.get(key) ?? [];

    const dailyLoads = new Array<number>(7).fill(0);
    const sports: Record<string, number> = {};

    for (const item of items) {
      const date = new Date(item.activity.start_date_local ?? item.activity.start_date);
      const dayIndex = clamp(Math.floor((date.getTime() - start.getTime()) / DAY_MS), 0, 6);
      dailyLoads[dayIndex] += item.load;
      const sport = item.activity.sport_type ?? "Sonstiges";
      sports[sport] = (sports[sport] ?? 0) + 1;
    }

    const load = dailyLoads.reduce((sum, v) => sum + v, 0);
    const spread = stdDev(dailyLoads);
    const monotony = spread > 0 ? mean(dailyLoads) / spread : 0;

    result.push({
      weekStart: key,
      sessions: items.length,
      hours: round(items.reduce((sum, i) => sum + i.hours, 0), 1),
      distanceKm: round(items.reduce((sum, i) => sum + (i.activity.distance ?? 0), 0) / 1000, 1),
      elevationM: Math.round(
        items.reduce((sum, i) => sum + (i.activity.total_elevation_gain ?? 0), 0),
      ),
      load: Math.round(load),
      monotony: round(monotony, 2),
      strain: Math.round(load * monotony),
      sports,
    });
  }

  return result;
}

/* -------------------------------------------------------------------------- */
/* Gesamtbild                                                                 */
/* -------------------------------------------------------------------------- */

export type TrainingSnapshot = {
  generatedAt: string;
  activityCount: number;
  firstActivity: string | null;
  lastActivity: string | null;
  references: AthleteReferences;
  fitness: {
    ctl: number;
    atl: number;
    tsb: number;
    /** Veraenderung der Fitness in den letzten 28 Tagen */
    ctlRamp28d: number;
    /** Belastung der letzten 7 Tage geteilt durch das 28-Tage-Wochenmittel */
    acwr: number;
    trend: "aufbauend" | "haltend" | "abbauend";
    formState: "frisch" | "ausgeglichen" | "ermuedet" | "stark ermuedet";
  };
  last7Days: PeriodTotals;
  last28Days: PeriodTotals;
  previous28Days: PeriodTotals;
  weeks: WeekSummary[];
  sportSplit: { sport: string; sessions: number; hours: number; share: number }[];
  intensityDistribution: { easy: number; moderate: number; hard: number };
  recentActivities: {
    date: string;
    name: string;
    sport: string;
    distanceKm: number;
    durationMin: number;
    elevationM: number;
    avgHr: number | null;
    avgPace: string | null;
    avgWatts: number | null;
    load: number;
    loadSource: LoadSource;
  }[];
  longestRecentSession: { date: string; sport: string; durationMin: number; distanceKm: number } | null;
  restDaysLast28: number;
  dataQuality: {
    heartrateCoverage: number;
    powerCoverage: number;
    loadSources: Record<LoadSource, number>;
  };
};

export type PeriodTotals = {
  sessions: number;
  hours: number;
  distanceKm: number;
  elevationM: number;
  load: number;
};

function totalsFor(scored: ScoredActivity[], fromMs: number, toMs: number): PeriodTotals {
  const items = scored.filter((item) => {
    const t = new Date(item.activity.start_date).getTime();
    return t >= fromMs && t < toMs;
  });

  return {
    sessions: items.length,
    hours: round(items.reduce((sum, i) => sum + i.hours, 0), 1),
    distanceKm: round(items.reduce((sum, i) => sum + (i.activity.distance ?? 0), 0) / 1000, 1),
    elevationM: Math.round(items.reduce((sum, i) => sum + (i.activity.total_elevation_gain ?? 0), 0)),
    load: Math.round(items.reduce((sum, i) => sum + i.load, 0)),
  };
}

export function formatPace(speedMetersPerSecond: number | null): string | null {
  if (!speedMetersPerSecond || speedMetersPerSecond <= 0) return null;
  const secondsPerKm = 1000 / speedMetersPerSecond;
  const minutes = Math.floor(secondsPerKm / 60);
  const seconds = Math.round(secondsPerKm % 60);
  const normalizedMinutes = seconds === 60 ? minutes + 1 : minutes;
  const normalizedSeconds = seconds === 60 ? 0 : seconds;
  return `${normalizedMinutes}:${String(normalizedSeconds).padStart(2, "0")} min/km`;
}

/**
 * Verdichtet die Rohdaten zu einem kompakten Lagebild. Dieses Objekt ist
 * gleichzeitig die Datengrundlage fuer die Oberflaeche und der Kontext,
 * den die KI zu sehen bekommt.
 */
export function buildSnapshot(athlete: Athlete, activities: Activity[]): TrainingSnapshot {
  const refs = deriveReferences(athlete, activities);
  const scored = activities.map((activity) => scoreActivity(activity, refs));
  const series = fitnessSeries(scored);

  const latest = series.at(-1) ?? { ctl: 0, atl: 0, tsb: 0, date: "", load: 0 };
  const monthAgo = series.at(-29) ?? series.at(0) ?? latest;
  const ctlRamp28d = round(latest.ctl - monthAgo.ctl);

  const now = Date.now();
  const last7 = totalsFor(scored, now - 7 * DAY_MS, now + DAY_MS);
  const last28 = totalsFor(scored, now - 28 * DAY_MS, now + DAY_MS);
  const previous28 = totalsFor(scored, now - 56 * DAY_MS, now - 28 * DAY_MS);

  const chronicWeekly = last28.load / 4;
  const acwr = chronicWeekly > 0 ? round(last7.load / chronicWeekly, 2) : 0;

  const trend: TrainingSnapshot["fitness"]["trend"] =
    ctlRamp28d > 3 ? "aufbauend" : ctlRamp28d < -3 ? "abbauend" : "haltend";

  const formState: TrainingSnapshot["fitness"]["formState"] =
    latest.tsb > 10 ? "frisch"
      : latest.tsb > -10 ? "ausgeglichen"
      : latest.tsb > -25 ? "ermuedet"
      : "stark ermuedet";

  // Sportarten-Verteilung ueber die letzten 90 Tage
  const recentWindow = scored.filter(
    (i) => new Date(i.activity.start_date).getTime() >= now - 90 * DAY_MS,
  );
  const sportTotals = new Map<string, { sessions: number; hours: number }>();
  for (const item of recentWindow) {
    const sport = item.activity.sport_type ?? "Sonstiges";
    const entry = sportTotals.get(sport) ?? { sessions: 0, hours: 0 };
    entry.sessions += 1;
    entry.hours += item.hours;
    sportTotals.set(sport, entry);
  }
  const totalHours = [...sportTotals.values()].reduce((sum, e) => sum + e.hours, 0);
  const sportSplit = [...sportTotals.entries()]
    .map(([sport, e]) => ({
      sport,
      sessions: e.sessions,
      hours: round(e.hours, 1),
      share: totalHours > 0 ? round((e.hours / totalHours) * 100) : 0,
    }))
    .sort((a, b) => b.hours - a.hours);

  // Intensitaetsverteilung nach Zeit (Naeherung ueber den Intensitaetsfaktor)
  let easy = 0;
  let moderate = 0;
  let hard = 0;
  for (const item of recentWindow) {
    if (item.intensity < 0.85) easy += item.hours;
    else if (item.intensity < 0.95) moderate += item.hours;
    else hard += item.hours;
  }
  const intensityTotal = easy + moderate + hard;
  const intensityDistribution =
    intensityTotal > 0
      ? {
          easy: round((easy / intensityTotal) * 100),
          moderate: round((moderate / intensityTotal) * 100),
          hard: round((hard / intensityTotal) * 100),
        }
      : { easy: 0, moderate: 0, hard: 0 };

  const recentActivities = scored.slice(0, 25).map((item) => ({
    date: toDayKey(item.activity.start_date_local ?? item.activity.start_date),
    name: item.activity.name ?? "Ohne Titel",
    sport: item.activity.sport_type ?? "Sonstiges",
    distanceKm: round((item.activity.distance ?? 0) / 1000, 2),
    durationMin: Math.round((item.activity.moving_time ?? 0) / 60),
    elevationM: Math.round(item.activity.total_elevation_gain ?? 0),
    avgHr: item.activity.average_heartrate ? Math.round(item.activity.average_heartrate) : null,
    avgPace: isRun(item.activity.sport_type) ? formatPace(item.activity.average_speed) : null,
    avgWatts: item.activity.average_watts ? Math.round(item.activity.average_watts) : null,
    load: item.load,
    loadSource: item.source,
  }));

  const longest = [...recentWindow].sort((a, b) => b.hours - a.hours)[0];

  const trainingDays = new Set(
    scored
      .filter((i) => new Date(i.activity.start_date).getTime() >= now - 28 * DAY_MS)
      .map((i) => toDayKey(i.activity.start_date_local ?? i.activity.start_date)),
  );

  const loadSources: Record<LoadSource, number> = { power: 0, heartrate: 0, pace: 0, duration: 0 };
  for (const item of recentWindow) loadSources[item.source] += 1;

  const withHr = recentWindow.filter((i) => i.activity.average_heartrate).length;
  const withPower = recentWindow.filter((i) => i.activity.average_watts).length;

  return {
    generatedAt: new Date().toISOString(),
    activityCount: activities.length,
    firstActivity: activities.at(-1)?.start_date ?? null,
    lastActivity: activities.at(0)?.start_date ?? null,
    references: refs,
    fitness: {
      ctl: latest.ctl,
      atl: latest.atl,
      tsb: latest.tsb,
      ctlRamp28d,
      acwr,
      trend,
      formState,
    },
    last7Days: last7,
    last28Days: last28,
    previous28Days: previous28,
    weeks: weeklySummaries(scored, 16),
    sportSplit,
    intensityDistribution,
    recentActivities,
    longestRecentSession: longest
      ? {
          date: toDayKey(longest.activity.start_date_local ?? longest.activity.start_date),
          sport: longest.activity.sport_type ?? "Sonstiges",
          durationMin: Math.round((longest.activity.moving_time ?? 0) / 60),
          distanceKm: round((longest.activity.distance ?? 0) / 1000, 1),
        }
      : null,
    restDaysLast28: 28 - trainingDays.size,
    dataQuality: {
      heartrateCoverage:
        recentWindow.length > 0 ? round((withHr / recentWindow.length) * 100) : 0,
      powerCoverage:
        recentWindow.length > 0 ? round((withPower / recentWindow.length) * 100) : 0,
      loadSources,
    },
  };
}

export { fitnessSeries as computeFitnessSeries };
