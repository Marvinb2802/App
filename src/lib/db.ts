import fs from "node:fs";
import path from "node:path";
import pg from "pg";

/**
 * Postgres-Anbindung. Ein Pool je Serverprozess; im Dev-Modus haengt er am
 * globalThis, weil Next.js das Modul bei jedem Hot-Reload neu auswertet.
 */

// BIGINT kommt sonst als Zeichenkette zurueck. Strava-IDs und COUNT(*) sollen
// Zahlen sein - beide liegen weit unter Number.MAX_SAFE_INTEGER.
pg.types.setTypeParser(pg.types.builtins.INT8, (value) => Number.parseInt(value, 10));

/**
 * Beide Treiber koennen dasselbe: eine Anweisung mit Positionsparametern
 * ausfuehren. Mehr braucht die App nicht.
 */
export type Executor = {
  query(sql: string, values: unknown[]): Promise<{ rows: unknown[] }>;
};

const globalForDb = globalThis as unknown as {
  __db?: Promise<Backend>;
  __migrated?: Promise<void>;
};

type Backend = {
  executor: Executor;
  /** Fuehrt mehrere Anweisungen gemeinsam aus; bei einem Fehler wird zurueckgerollt. */
  transaction<T>(run: (tx: Executor) => Promise<T>): Promise<T>;
  label: string;
};

export class DatabaseNotConfiguredError extends Error {
  constructor() {
    super("DATABASE_URL fehlt. Trage die Verbindung zu deiner Postgres-Datenbank in .env.local ein.");
    this.name = "DatabaseNotConfiguredError";
  }
}

/**
 * Ohne DATABASE_URL laeuft die App in der Entwicklung auf einem eingebetteten
 * Postgres (PGlite), das seine Daten unter ./data/pgdata ablegt. So kann man
 * die App ansehen, ohne vorher eine Datenbank einzurichten.
 * In Produktion gibt es diesen Rueckfall nicht: dort fehlt in der Regel ein
 * dauerhaftes Dateisystem, und stillschweigend verschwindende Daten waeren
 * schlimmer als eine klare Fehlermeldung.
 */
export function isDatabaseConfigured(): boolean {
  return Boolean(process.env.DATABASE_URL) || process.env.NODE_ENV !== "production";
}

async function createBackend(): Promise<Backend> {
  const connectionString = process.env.DATABASE_URL;

  if (connectionString) {
    // TLS wird nicht hier festgelegt, sondern aus der Verbindungszeichenkette
    // gelesen: "sslmode=require" prueft bei node-postgres das Zertifikat
    // vollstaendig. Frueher wurde die Pruefung hier abgeschaltet - unnoetig,
    // denn Neon und Supabase haben gueltige Zertifikate. Wer einen Server mit
    // selbst signiertem Zertifikat nutzt, haengt "sslmode=no-verify" an.
    const pool = new pg.Pool({ connectionString, max: 5 });

    return {
      executor: pool,
      label: "Postgres",
      async transaction(run) {
        const client = await pool.connect();
        try {
          await client.query("BEGIN");
          const result = await run(client);
          await client.query("COMMIT");
          return result;
        } catch (error) {
          await client.query("ROLLBACK");
          throw error;
        } finally {
          client.release();
        }
      },
    };
  }

  if (process.env.NODE_ENV === "production") throw new DatabaseNotConfiguredError();

  const { PGlite } = await import("@electric-sql/pglite");
  const directory = path.join(process.cwd(), "data", "pgdata");
  fs.mkdirSync(directory, { recursive: true }); // PGlite legt den Ordner nicht selbst an
  const pglite = new PGlite(directory);
  console.info(
    "[db] Kein DATABASE_URL gesetzt - es laeuft ein eingebettetes Postgres unter ./data/pgdata.",
  );

  return {
    executor: pglite,
    label: "PGlite (eingebettet)",
    transaction: (run) => pglite.transaction((tx) => run(tx)),
  };
}

function getBackend(): Promise<Backend> {
  if (!globalForDb.__db) {
    globalForDb.__db = createBackend().catch((error: unknown) => {
      globalForDb.__db = undefined;
      throw error;
    });
  }
  return globalForDb.__db;
}

/**
 * Uebersetzt benannte Platzhalter (@name) in die von Postgres erwartete
 * Positionsform ($1, $2, ...). Das haelt die langen INSERT-Anweisungen lesbar.
 */
function bindNamed(text: string, params: Record<string, unknown>): [string, unknown[]] {
  const values: unknown[] = [];
  const positions = new Map<string, number>();

  const translated = text.replace(/@([a-zA-Z_][a-zA-Z0-9_]*)/g, (_match, name: string) => {
    const known = positions.get(name);
    if (known !== undefined) return `$${known}`;

    if (!(name in params)) {
      throw new Error(`Platzhalter @${name} wurde nicht mit einem Wert belegt.`);
    }
    values.push(params[name]);
    const position = values.length;
    positions.set(name, position);
    return `$${position}`;
  });

  return [translated, values];
}

type Params = unknown[] | Record<string, unknown>;

function prepare(text: string, params?: Params): [string, unknown[]] {
  if (params === undefined) return [text, []];
  if (Array.isArray(params)) return [text, params];
  return bindNamed(text, params);
}

/** Alle Zeilen einer Abfrage. */
export async function queryAll<T>(text: string, params?: Params): Promise<T[]> {
  await ensureMigrated();
  const [sql, values] = prepare(text, params);
  const { executor } = await getBackend();
  const result = await executor.query(sql, values);
  return result.rows as T[];
}

/** Die erste Zeile einer Abfrage, oder null. */
export async function queryOne<T>(text: string, params?: Params): Promise<T | null> {
  const rows = await queryAll<T>(text, params);
  return rows[0] ?? null;
}

/** Schreibender Zugriff ohne Ergebnis. */
export async function execute(text: string, params?: Params): Promise<void> {
  await queryAll(text, params);
}

/**
 * Fuehrt mehrere Anweisungen auf einer Verbindung als eine Transaktion aus.
 * Bei einem Fehler wird alles zurueckgerollt.
 */
export async function transaction<T>(run: (tx: Executor) => Promise<T>): Promise<T> {
  await ensureMigrated();
  const backend = await getBackend();
  return backend.transaction(run);
}

/** Wie `prepare`, aber fuer Anweisungen innerhalb einer Transaktion. */
export function bind(text: string, params?: Params): [string, unknown[]] {
  return prepare(text, params);
}

/* -------------------------------------------------------------------------- */
/* Schema                                                                     */
/* -------------------------------------------------------------------------- */

/** Zeitstempel als Text, damit die Werte ueberall gleich aussehen. */
const NOW = "to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS')";

const SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS athletes (
  id             BIGINT PRIMARY KEY,
  firstname      TEXT,
  lastname       TEXT,
  profile        TEXT,
  city           TEXT,
  country        TEXT,
  sex            TEXT,
  weight_kg      DOUBLE PRECISION,
  ftp            INTEGER,
  max_hr         INTEGER,
  rest_hr        INTEGER,
  threshold_hr   INTEGER,
  threshold_pace DOUBLE PRECISION,
  goal           TEXT,
  created_at     TEXT NOT NULL DEFAULT ${NOW},
  updated_at     TEXT NOT NULL DEFAULT ${NOW}
  )`,
  `CREATE TABLE IF NOT EXISTS tokens (
  athlete_id    BIGINT PRIMARY KEY REFERENCES athletes(id) ON DELETE CASCADE,
  access_token  TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  expires_at    BIGINT NOT NULL,
  scope         TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS activities (
  id                     BIGINT PRIMARY KEY,
  athlete_id             BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  name                   TEXT,
  sport_type             TEXT,
  start_date             TEXT NOT NULL,
  start_date_local       TEXT,
  distance               DOUBLE PRECISION,
  moving_time            INTEGER,
  elapsed_time           INTEGER,
  total_elevation_gain   DOUBLE PRECISION,
  average_speed          DOUBLE PRECISION,
  max_speed              DOUBLE PRECISION,
  average_heartrate      DOUBLE PRECISION,
  max_heartrate          DOUBLE PRECISION,
  average_watts          DOUBLE PRECISION,
  weighted_average_watts DOUBLE PRECISION,
  kilojoules             DOUBLE PRECISION,
  average_cadence        DOUBLE PRECISION,
  suffer_score           DOUBLE PRECISION,
  has_heartrate          INTEGER NOT NULL DEFAULT 0,
  trainer                INTEGER NOT NULL DEFAULT 0,
  synced_at              TEXT NOT NULL DEFAULT ${NOW}
  )`,
  `CREATE INDEX IF NOT EXISTS idx_activities_athlete_date
  ON activities(athlete_id, start_date DESC)`,
  `CREATE TABLE IF NOT EXISTS sync_state (
  athlete_id     BIGINT PRIMARY KEY REFERENCES athletes(id) ON DELETE CASCADE,
  last_synced_at TEXT,
  last_error     TEXT
  )`,
  `CREATE TABLE IF NOT EXISTS ai_reports (
  id         BIGSERIAL PRIMARY KEY,
  athlete_id BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  kind       TEXT NOT NULL,
  payload    TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT ${NOW}
  )`,
  `CREATE INDEX IF NOT EXISTS idx_reports_athlete
  ON ai_reports(athlete_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS plans (
  id          BIGSERIAL PRIMARY KEY,
  athlete_id  BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  goal        TEXT NOT NULL,
  target_date TEXT,
  weeks       INTEGER NOT NULL,
  payload     TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT ${NOW}
  )`,
  `CREATE INDEX IF NOT EXISTS idx_plans_athlete
  ON plans(athlete_id, created_at DESC)`,
  `CREATE TABLE IF NOT EXISTS chat_messages (
  id         BIGSERIAL PRIMARY KEY,
  athlete_id BIGINT NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
  role       TEXT NOT NULL,
  content    TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT ${NOW}
  )`,
  `CREATE INDEX IF NOT EXISTS idx_chat_athlete
  ON chat_messages(athlete_id, id)`,
];

/** Legt das Schema beim ersten Zugriff an. Laeuft genau einmal je Prozess. */
function ensureMigrated(): Promise<void> {
  if (!globalForDb.__migrated) {
    globalForDb.__migrated = getBackend()
      .then(async ({ executor }) => {
        // Einzeln statt als ein Skript: gepoolte Verbindungen (etwa Neons
        // PgBouncer) und PGlite nehmen pro Aufruf nur eine Anweisung an.
        for (const statement of SCHEMA) await executor.query(statement, []);
      })
      .catch((error: unknown) => {
        // Ein Fehlschlag darf sich nicht als "erledigt" merken.
        globalForDb.__migrated = undefined;
        throw error;
      });
  }
  return globalForDb.__migrated;
}

/** Der Zeitstempel-Ausdruck, damit Aufrufer ihn in eigenen Anweisungen nutzen. */
export const NOW_SQL = NOW;
