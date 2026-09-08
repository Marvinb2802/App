import { getDb } from "@/lib/db";
import type { Activity, StoredTokens } from "@/lib/types";

const OAUTH_BASE = "https://www.strava.com/oauth";
const API_BASE = "https://www.strava.com/api/v3";

/**
 * Berechtigungen, die die App anfragt:
 *  - read                 Basis-Profil
 *  - activity:read_all     alle Aktivitaeten, auch die privaten
 *  - profile:read_all      Herzfrequenz-/Leistungszonen
 */
const SCOPE = "read,activity:read_all,profile:read_all";

export class StravaNotConfiguredError extends Error {
  constructor() {
    super(
      "Strava ist nicht konfiguriert: STRAVA_CLIENT_ID und STRAVA_CLIENT_SECRET fehlen.",
    );
    this.name = "StravaNotConfiguredError";
  }
}

export class StravaApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "StravaApiError";
  }
}

export function isStravaConfigured(): boolean {
  return Boolean(process.env.STRAVA_CLIENT_ID && process.env.STRAVA_CLIENT_SECRET);
}

function credentials(): { clientId: string; clientSecret: string } {
  const clientId = process.env.STRAVA_CLIENT_ID;
  const clientSecret = process.env.STRAVA_CLIENT_SECRET;
  if (!clientId || !clientSecret) throw new StravaNotConfiguredError();
  return { clientId, clientSecret };
}

export function appUrl(): string {
  return (process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "");
}

export function redirectUri(): string {
  return `${appUrl()}/api/auth/strava/callback`;
}

export function authorizeUrl(state: string): string {
  const { clientId } = credentials();
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri(),
    response_type: "code",
    approval_prompt: "auto",
    scope: SCOPE,
  });
  params.set("state", state);
  return `${OAUTH_BASE}/authorize?${params.toString()}`;
}

type TokenResponse = {
  access_token: string;
  refresh_token: string;
  expires_at: number;
  scope?: string;
  athlete?: StravaAthlete;
};

export type StravaAthlete = {
  id: number;
  firstname?: string | null;
  lastname?: string | null;
  profile?: string | null;
  city?: string | null;
  country?: string | null;
  sex?: string | null;
  weight?: number | null;
  ftp?: number | null;
};

async function postToken(body: Record<string, string>): Promise<TokenResponse> {
  const { clientId, clientSecret } = credentials();
  const response = await fetch(`${OAUTH_BASE}/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, ...body }),
    cache: "no-store",
  });

  if (!response.ok) {
    throw new StravaApiError(
      `Strava-Token-Anfrage fehlgeschlagen: ${await response.text()}`,
      response.status,
    );
  }
  return (await response.json()) as TokenResponse;
}

export function exchangeCodeForTokens(code: string): Promise<TokenResponse> {
  return postToken({ code, grant_type: "authorization_code" });
}

/** Liefert ein gueltiges Access-Token und erneuert es bei Bedarf. */
export async function getFreshAccessToken(athleteId: number): Promise<string> {
  const db = getDb();
  const tokens = db
    .prepare("SELECT * FROM tokens WHERE athlete_id = ?")
    .get(athleteId) as StoredTokens | undefined;

  if (!tokens) throw new StravaApiError("Keine Strava-Verbindung fuer diesen Athleten.", 401);

  // 60 Sekunden Puffer, damit ein Token nicht mitten im Request ablaeuft.
  const stillValid = tokens.expires_at - 60 > Math.floor(Date.now() / 1000);
  if (stillValid) return tokens.access_token;

  const refreshed = await postToken({
    grant_type: "refresh_token",
    refresh_token: tokens.refresh_token,
  });

  db.prepare(
    `UPDATE tokens SET access_token = ?, refresh_token = ?, expires_at = ? WHERE athlete_id = ?`,
  ).run(refreshed.access_token, refreshed.refresh_token, refreshed.expires_at, athleteId);

  return refreshed.access_token;
}

async function apiGet<T>(athleteId: number, path: string): Promise<T> {
  const token = await getFreshAccessToken(athleteId);
  const response = await fetch(`${API_BASE}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });

  if (response.status === 429) {
    throw new StravaApiError(
      "Strava-Rate-Limit erreicht (100 Anfragen / 15 Min). Bitte spaeter erneut synchronisieren.",
      429,
    );
  }
  if (!response.ok) {
    throw new StravaApiError(`Strava-API-Fehler ${response.status}`, response.status);
  }
  return (await response.json()) as T;
}

export function saveTokens(
  athleteId: number,
  tokens: { access_token: string; refresh_token: string; expires_at: number; scope?: string },
): void {
  getDb()
    .prepare(
      `INSERT INTO tokens (athlete_id, access_token, refresh_token, expires_at, scope)
       VALUES (@athlete_id, @access_token, @refresh_token, @expires_at, @scope)
       ON CONFLICT(athlete_id) DO UPDATE SET
         access_token  = excluded.access_token,
         refresh_token = excluded.refresh_token,
         expires_at    = excluded.expires_at,
         scope         = excluded.scope`,
    )
    .run({
      athlete_id: athleteId,
      access_token: tokens.access_token,
      refresh_token: tokens.refresh_token,
      expires_at: tokens.expires_at,
      scope: tokens.scope ?? null,
    });
}

export function upsertAthlete(athlete: StravaAthlete): void {
  getDb()
    .prepare(
      `INSERT INTO athletes (id, firstname, lastname, profile, city, country, sex, weight_kg, ftp)
       VALUES (@id, @firstname, @lastname, @profile, @city, @country, @sex, @weight_kg, @ftp)
       ON CONFLICT(id) DO UPDATE SET
         firstname  = excluded.firstname,
         lastname   = excluded.lastname,
         profile    = excluded.profile,
         city       = excluded.city,
         country    = excluded.country,
         sex        = excluded.sex,
         weight_kg  = COALESCE(excluded.weight_kg, athletes.weight_kg),
         ftp        = COALESCE(excluded.ftp, athletes.ftp),
         updated_at = datetime('now')`,
    )
    .run({
      id: athlete.id,
      firstname: athlete.firstname ?? null,
      lastname: athlete.lastname ?? null,
      profile: athlete.profile ?? null,
      city: athlete.city ?? null,
      country: athlete.country ?? null,
      sex: athlete.sex ?? null,
      weight_kg: athlete.weight ?? null,
      ftp: athlete.ftp ?? null,
    });
}

export type SummaryActivity = {
  id: number;
  name?: string | null;
  sport_type?: string | null;
  type?: string | null;
  start_date: string;
  start_date_local?: string | null;
  distance?: number | null;
  moving_time?: number | null;
  elapsed_time?: number | null;
  total_elevation_gain?: number | null;
  average_speed?: number | null;
  max_speed?: number | null;
  average_heartrate?: number | null;
  max_heartrate?: number | null;
  average_watts?: number | null;
  weighted_average_watts?: number | null;
  kilojoules?: number | null;
  average_cadence?: number | null;
  suffer_score?: number | null;
  has_heartrate?: boolean;
  trainer?: boolean;
};

const insertActivity = `
  INSERT INTO activities (
    id, athlete_id, name, sport_type, start_date, start_date_local, distance,
    moving_time, elapsed_time, total_elevation_gain, average_speed, max_speed,
    average_heartrate, max_heartrate, average_watts, weighted_average_watts,
    kilojoules, average_cadence, suffer_score, has_heartrate, trainer, synced_at
  ) VALUES (
    @id, @athlete_id, @name, @sport_type, @start_date, @start_date_local, @distance,
    @moving_time, @elapsed_time, @total_elevation_gain, @average_speed, @max_speed,
    @average_heartrate, @max_heartrate, @average_watts, @weighted_average_watts,
    @kilojoules, @average_cadence, @suffer_score, @has_heartrate, @trainer, datetime('now')
  )
  ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    sport_type = excluded.sport_type,
    distance = excluded.distance,
    moving_time = excluded.moving_time,
    elapsed_time = excluded.elapsed_time,
    total_elevation_gain = excluded.total_elevation_gain,
    average_speed = excluded.average_speed,
    max_speed = excluded.max_speed,
    average_heartrate = excluded.average_heartrate,
    max_heartrate = excluded.max_heartrate,
    average_watts = excluded.average_watts,
    weighted_average_watts = excluded.weighted_average_watts,
    kilojoules = excluded.kilojoules,
    average_cadence = excluded.average_cadence,
    suffer_score = excluded.suffer_score,
    has_heartrate = excluded.has_heartrate,
    trainer = excluded.trainer,
    synced_at = datetime('now')
`;

export function storeActivities(athleteId: number, activities: SummaryActivity[]): number {
  const db = getDb();
  const statement = db.prepare(insertActivity);

  const run = db.transaction((items: SummaryActivity[]) => {
    for (const item of items) {
      statement.run({
        id: item.id,
        athlete_id: athleteId,
        name: item.name ?? null,
        sport_type: item.sport_type ?? item.type ?? null,
        start_date: item.start_date,
        start_date_local: item.start_date_local ?? null,
        distance: item.distance ?? null,
        moving_time: item.moving_time ?? null,
        elapsed_time: item.elapsed_time ?? null,
        total_elevation_gain: item.total_elevation_gain ?? null,
        average_speed: item.average_speed ?? null,
        max_speed: item.max_speed ?? null,
        average_heartrate: item.average_heartrate ?? null,
        max_heartrate: item.max_heartrate ?? null,
        average_watts: item.average_watts ?? null,
        weighted_average_watts: item.weighted_average_watts ?? null,
        kilojoules: item.kilojoules ?? null,
        average_cadence: item.average_cadence ?? null,
        suffer_score: item.suffer_score ?? null,
        has_heartrate: item.has_heartrate ? 1 : 0,
        trainer: item.trainer ? 1 : 0,
      });
    }
  });

  run(activities);
  return activities.length;
}

/**
 * Holt Aktivitaeten seit `afterEpoch` (Default: letzte 365 Tage) und schreibt sie
 * in die Datenbank. Strava liefert maximal 200 Aktivitaeten pro Seite.
 */
export async function syncActivities(
  athleteId: number,
  options: { afterEpoch?: number; maxPages?: number } = {},
): Promise<{ imported: number }> {
  const after =
    options.afterEpoch ?? Math.floor(Date.now() / 1000) - 365 * 24 * 60 * 60;
  const maxPages = options.maxPages ?? 10;

  let imported = 0;
  for (let page = 1; page <= maxPages; page++) {
    const batch = await apiGet<SummaryActivity[]>(
      athleteId,
      `/athlete/activities?after=${after}&per_page=200&page=${page}`,
    );
    if (batch.length === 0) break;
    imported += storeActivities(athleteId, batch);
    if (batch.length < 200) break;
  }

  getDb()
    .prepare(
      `INSERT INTO sync_state (athlete_id, last_synced_at, last_error)
       VALUES (?, datetime('now'), NULL)
       ON CONFLICT(athlete_id) DO UPDATE SET
         last_synced_at = datetime('now'), last_error = NULL`,
    )
    .run(athleteId);

  return { imported };
}

type ZoneResponse = {
  heart_rate?: { custom_zones?: boolean; zones?: { min: number; max: number }[] };
  power?: { zones?: { min: number; max: number }[] };
};

/**
 * Uebernimmt die in Strava hinterlegten HF-Zonen als Schaetzung fuer
 * Maximal- und Schwellenherzfrequenz, falls dort etwas gepflegt ist.
 */
export async function syncAthleteZones(athleteId: number): Promise<void> {
  let zones: ZoneResponse;
  try {
    zones = await apiGet<ZoneResponse>(athleteId, "/athlete/zones");
  } catch {
    return; // Zonen sind optional - fehlender Scope darf den Sync nicht kippen.
  }

  const hrZones = zones.heart_rate?.zones ?? [];
  if (hrZones.length === 0) return;

  const maxHr = hrZones[hrZones.length - 1]?.max;
  // Untergrenze der vorletzten Zone ist eine brauchbare Naeherung der Schwelle.
  const thresholdHr = hrZones[hrZones.length - 2]?.min ?? hrZones[hrZones.length - 1]?.min;

  getDb()
    .prepare(
      `UPDATE athletes
          SET max_hr = COALESCE(?, max_hr),
              threshold_hr = COALESCE(?, threshold_hr),
              updated_at = datetime('now')
        WHERE id = ?`,
    )
    .run(maxHr && maxHr > 0 ? maxHr : null, thresholdHr && thresholdHr > 0 ? thresholdHr : null, athleteId);
}

export function listActivities(athleteId: number, limit = 500): Activity[] {
  return getDb()
    .prepare(
      "SELECT * FROM activities WHERE athlete_id = ? ORDER BY start_date DESC LIMIT ?",
    )
    .all(athleteId, limit) as Activity[];
}

export function lastSyncedAt(athleteId: number): string | null {
  const row = getDb()
    .prepare("SELECT last_synced_at FROM sync_state WHERE athlete_id = ?")
    .get(athleteId) as { last_synced_at: string | null } | undefined;
  return row?.last_synced_at ?? null;
}
