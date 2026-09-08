"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

export function SyncButton({ lastSyncedAt }: { lastSyncedAt: string | null }) {
  const router = useRouter();
  const [state, setState] = useState<{ busy: boolean; message: string | null }>({
    busy: false,
    message: null,
  });

  async function sync() {
    setState({ busy: true, message: null });
    const response = await fetch("/api/strava/sync", { method: "POST" });
    const data = (await response.json()) as { imported?: number; note?: string; error?: string };

    if (!response.ok) {
      setState({ busy: false, message: data.error ?? "Synchronisierung fehlgeschlagen." });
      return;
    }

    setState({
      busy: false,
      message: data.note ?? `${data.imported ?? 0} Aktivitäten aktualisiert.`,
    });
    router.refresh();
  }

  return (
    <div className="text-right">
      <button
        type="button"
        onClick={sync}
        disabled={state.busy}
        className="rounded-lg border border-ink-700 px-4 py-2 text-sm text-ink-100 transition hover:bg-ink-800 disabled:opacity-50"
      >
        {state.busy ? "Synchronisiere …" : "Mit Strava synchronisieren"}
      </button>
      <p className="mt-1.5 text-xs text-ink-500">
        {state.message ?? (lastSyncedAt ? `Zuletzt: ${lastSyncedAt} UTC` : "Noch nie synchronisiert")}
      </p>
    </div>
  );
}
