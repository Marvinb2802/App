"use client";

/**
 * Auffangseite fuer Fehler, die beim Rendern auf dem Server auftreten.
 * Der haeufigste Fall bei der Einrichtung ist eine fehlende Datenbank.
 */
export default function ErrorPage({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const missingDatabase = error.message.includes("DATABASE_URL");

  return (
    <div className="mx-auto max-w-2xl py-16">
      <h1 className="text-2xl font-semibold tracking-tight">
        {missingDatabase ? "Die Datenbank fehlt noch" : "Da ist etwas schiefgegangen"}
      </h1>

      {missingDatabase ? (
        <div className="mt-4 space-y-4 text-ink-300">
          <p>
            Pacer braucht eine Postgres-Datenbank. Lege eine kostenlose an (etwa bei Neon
            oder Supabase), kopiere die Verbindungszeichenkette und trage sie in die Datei{" "}
            <code className="rounded bg-ink-900 px-1.5 py-0.5 text-ink-100">.env.local</code> ein:
          </p>
          <pre className="overflow-x-auto rounded-xl border border-ink-800 bg-ink-900 px-4 py-3 text-sm text-ink-100">
            DATABASE_URL=postgresql://benutzer:passwort@host/datenbank?sslmode=require
          </pre>
          <p className="text-sm text-ink-500">
            Danach den Server neu starten. Die Tabellen legt Pacer beim ersten Aufruf selbst an.
          </p>
        </div>
      ) : (
        <p className="mt-4 leading-relaxed text-ink-300">{error.message}</p>
      )}

      <button
        type="button"
        onClick={reset}
        className="mt-8 rounded-lg bg-brand px-5 py-2.5 font-medium text-white transition hover:bg-brand-dark"
      >
        Erneut versuchen
      </button>
    </div>
  );
}
