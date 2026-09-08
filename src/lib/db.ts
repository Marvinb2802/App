import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

/**
 * Eine einzige SQLite-Verbindung fuer den gesamten Serverprozess.
 * Im Next.js-Dev-Modus wird das Modul bei jedem Hot-Reload neu ausgewertet,
 * darum haengt die Verbindung am globalThis-Objekt.
 */
const globalForDb = globalThis as unknown as { __db?: Database.Database };

function createConnection(): Database.Database {
  const file = process.env.DATABASE_PATH ?? path.join(process.cwd(), "data", "app.db");
  fs.mkdirSync(path.dirname(file), { recursive: true });

  const db = new Database(file);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  migrate(db);
  return db;
}

function migrate(db: Database.Database): void {
  db.exec(`
    CREATE TABLE IF NOT EXISTS athletes (
      id             INTEGER PRIMARY KEY,
      firstname      TEXT,
      lastname       TEXT,
      profile        TEXT,
      city           TEXT,
      country        TEXT,
      sex            TEXT,
      weight_kg      REAL,
      ftp            INTEGER,
      max_hr         INTEGER,
      rest_hr        INTEGER,
      threshold_hr   INTEGER,
      threshold_pace REAL,      -- Schwellentempo in m/s
      goal           TEXT,      -- Freitext-Saisonziel
      created_at     TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS tokens (
      athlete_id    INTEGER PRIMARY KEY REFERENCES athletes(id) ON DELETE CASCADE,
      access_token  TEXT NOT NULL,
      refresh_token TEXT NOT NULL,
      expires_at    INTEGER NOT NULL,   -- Unix-Sekunden
      scope         TEXT
    );

    CREATE TABLE IF NOT EXISTS activities (
      id                     INTEGER PRIMARY KEY,
      athlete_id             INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
      name                   TEXT,
      sport_type             TEXT,
      start_date             TEXT NOT NULL,   -- ISO-8601 UTC
      start_date_local       TEXT,
      distance               REAL,            -- Meter
      moving_time            INTEGER,         -- Sekunden
      elapsed_time           INTEGER,
      total_elevation_gain   REAL,            -- Meter
      average_speed          REAL,            -- m/s
      max_speed              REAL,
      average_heartrate      REAL,
      max_heartrate          REAL,
      average_watts          REAL,
      weighted_average_watts REAL,
      kilojoules             REAL,
      average_cadence        REAL,
      suffer_score           REAL,
      has_heartrate          INTEGER NOT NULL DEFAULT 0,
      trainer                INTEGER NOT NULL DEFAULT 0,
      synced_at              TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_activities_athlete_date
      ON activities(athlete_id, start_date DESC);

    CREATE TABLE IF NOT EXISTS sync_state (
      athlete_id     INTEGER PRIMARY KEY REFERENCES athletes(id) ON DELETE CASCADE,
      last_synced_at TEXT,
      last_error     TEXT
    );

    CREATE TABLE IF NOT EXISTS ai_reports (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
      kind       TEXT NOT NULL,        -- 'analysis'
      payload    TEXT NOT NULL,        -- JSON
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_reports_athlete
      ON ai_reports(athlete_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS plans (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
      goal       TEXT NOT NULL,
      target_date TEXT,
      weeks      INTEGER NOT NULL,
      payload    TEXT NOT NULL,        -- JSON
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_plans_athlete
      ON plans(athlete_id, created_at DESC);

    CREATE TABLE IF NOT EXISTS chat_messages (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      athlete_id INTEGER NOT NULL REFERENCES athletes(id) ON DELETE CASCADE,
      role       TEXT NOT NULL,        -- 'user' | 'assistant'
      content    TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_chat_athlete
      ON chat_messages(athlete_id, id);
  `);
}

export function getDb(): Database.Database {
  if (!globalForDb.__db) globalForDb.__db = createConnection();
  return globalForDb.__db;
}
