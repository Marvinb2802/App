"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Card } from "@/components/ui";
import type { Athlete } from "@/lib/types";

type Values = {
  weight_kg: string;
  max_hr: string;
  rest_hr: string;
  threshold_hr: string;
  ftp: string;
  threshold_pace: string;
  goal: string;
};

/** "4:10" oder "4:10 min/km" -> Geschwindigkeit in m/s. Leer -> null. */
function paceToSpeed(value: string): number | null {
  const match = value.trim().match(/^(\d{1,2})[:.](\d{1,2})/);
  if (!match) return null;
  const secondsPerKm = Number(match[1]) * 60 + Number(match[2]);
  return secondsPerKm > 0 ? Number((1000 / secondsPerKm).toFixed(3)) : null;
}

/** Umkehrung fuer die Anzeige im Feld. */
function speedToPace(speed: number | null): string {
  if (!speed || speed <= 0) return "";
  const secondsPerKm = Math.round(1000 / speed);
  return `${Math.floor(secondsPerKm / 60)}:${String(secondsPerKm % 60).padStart(2, "0")}`;
}

function toNumberOrNull(value: string): number | null {
  const trimmed = value.trim();
  if (trimmed === "") return null;
  const parsed = Number(trimmed.replace(",", "."));
  return Number.isFinite(parsed) ? parsed : null;
}

export function SettingsForm({ athlete }: { athlete: Athlete }) {
  const router = useRouter();
  const [values, setValues] = useState<Values>({
    weight_kg: athlete.weight_kg?.toString() ?? "",
    max_hr: athlete.max_hr?.toString() ?? "",
    rest_hr: athlete.rest_hr?.toString() ?? "",
    threshold_hr: athlete.threshold_hr?.toString() ?? "",
    ftp: athlete.ftp?.toString() ?? "",
    threshold_pace: speedToPace(athlete.threshold_pace),
    goal: athlete.goal ?? "",
  });
  const [status, setStatus] = useState<{ kind: "ok" | "fehler"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setStatus(null);

    const response = await fetch("/api/athlete", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        weight_kg: toNumberOrNull(values.weight_kg),
        max_hr: toNumberOrNull(values.max_hr),
        rest_hr: toNumberOrNull(values.rest_hr),
        threshold_hr: toNumberOrNull(values.threshold_hr),
        ftp: toNumberOrNull(values.ftp),
        threshold_pace: paceToSpeed(values.threshold_pace),
        goal: values.goal.trim() === "" ? null : values.goal.trim(),
      }),
    });

    const data = (await response.json()) as { error?: string };
    setBusy(false);

    if (!response.ok) {
      setStatus({ kind: "fehler", text: data.error ?? "Speichern fehlgeschlagen." });
      return;
    }

    setStatus({ kind: "ok", text: "Gespeichert. Die Kennzahlen werden neu berechnet." });
    router.refresh();
  }

  return (
    <form onSubmit={submit} className="space-y-6">
      <Card
        title="Referenzwerte"
        subtitle="Je genauer diese Werte, desto präziser die Belastungsberechnung. Leer lassen heißt: die App schätzt."
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            label="Maximale Herzfrequenz"
            unit="bpm"
            hint="Höchster Wert, den du im Wettkampf je gesehen hast"
            value={values.max_hr}
            onChange={(v) => setValues({ ...values, max_hr: v })}
          />
          <Field
            label="Schwellenherzfrequenz"
            unit="bpm"
            hint="Durchschnitts-HF, die du eine Stunde lang hältst (etwa 90 % der Max-HF)"
            value={values.threshold_hr}
            onChange={(v) => setValues({ ...values, threshold_hr: v })}
          />
          <Field
            label="Ruheherzfrequenz"
            unit="bpm"
            hint="Morgens im Liegen gemessen"
            value={values.rest_hr}
            onChange={(v) => setValues({ ...values, rest_hr: v })}
          />
          <Field
            label="FTP"
            unit="Watt"
            hint="Funktionelle Schwellenleistung auf dem Rad"
            value={values.ftp}
            onChange={(v) => setValues({ ...values, ftp: v })}
          />
          <Field
            label="Schwellentempo Laufen"
            unit="min/km"
            hint="Tempo, das du rund eine Stunde durchhältst, z. B. 4:10"
            value={values.threshold_pace}
            onChange={(v) => setValues({ ...values, threshold_pace: v })}
          />
          <Field
            label="Gewicht"
            unit="kg"
            value={values.weight_kg}
            onChange={(v) => setValues({ ...values, weight_kg: v })}
          />
        </div>
      </Card>

      <Card title="Saisonziel" subtitle="Die KI berücksichtigt es in Analyse, Plan und Chat.">
        <textarea
          rows={3}
          value={values.goal}
          onChange={(event) => setValues({ ...values, goal: event.target.value })}
          placeholder="z. B. Marathon in Berlin unter 3:15 h, Ende September"
          className="w-full rounded-lg border border-ink-700 bg-ink-900 px-3 py-2 text-ink-100 outline-none transition focus:border-brand-light"
        />
      </Card>

      <div className="flex flex-wrap items-center gap-4">
        <button
          type="submit"
          disabled={busy}
          className="rounded-lg bg-brand px-5 py-2.5 font-medium text-white transition hover:bg-brand-dark disabled:opacity-50"
        >
          {busy ? "Speichert …" : "Speichern"}
        </button>
        {status && (
          <span className={status.kind === "ok" ? "text-sm text-emerald-400" : "text-sm text-red-400"}>
            {status.text}
          </span>
        )}
      </div>
    </form>
  );
}

function Field({
  label,
  unit,
  hint,
  value,
  onChange,
}: {
  label: string;
  unit: string;
  hint?: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm text-ink-300">
        {label} <span className="text-ink-500">({unit})</span>
      </span>
      <input
        inputMode="decimal"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="w-full rounded-lg border border-ink-700 bg-ink-900 px-3 py-2 text-ink-100 outline-none transition focus:border-brand-light"
      />
      {hint && <span className="mt-1 block text-xs leading-snug text-ink-500">{hint}</span>}
    </label>
  );
}
