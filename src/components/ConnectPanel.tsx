"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function ConnectPanel({ stravaConfigured }: { stravaConfigured: boolean }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function startDemo() {
    setBusy(true);
    const response = await fetch("/api/auth/demo", { method: "POST" });
    if (!response.ok) {
      setBusy(false);
      return;
    }
    router.refresh();
    router.push("/");
  }

  return (
    <div className="flex flex-col gap-3 sm:flex-row">
      {stravaConfigured ? (
        <a
          href="/api/auth/strava"
          className="inline-flex items-center justify-center gap-2 rounded-lg bg-strava px-5 py-3 font-medium text-white transition hover:bg-strava-dark"
        >
          Mit Strava verbinden
        </a>
      ) : (
        <span className="inline-flex items-center justify-center rounded-lg border border-ink-700 bg-ink-900 px-5 py-3 text-sm text-ink-500">
          Strava-Zugang nicht konfiguriert – siehe README
        </span>
      )}

      <button
        type="button"
        onClick={startDemo}
        disabled={busy}
        className="inline-flex items-center justify-center rounded-lg border border-ink-700 px-5 py-3 font-medium text-ink-100 transition hover:bg-ink-800 disabled:opacity-50"
      >
        {busy ? "Wird geladen …" : "Mit Demo-Daten ansehen"}
      </button>
    </div>
  );
}
