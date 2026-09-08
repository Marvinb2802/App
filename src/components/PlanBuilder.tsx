"use client";

import { useState } from "react";
import type { PlanSession, PlanWeek, TrainingPlan } from "@/lib/ai-schemas";
import { Badge, Card } from "@/components/ui";

const SESSION_TONE: Record<PlanSession["type"], string> = {
  Ruhetag: "border-ink-700 bg-ink-900/40 text-ink-500",
  Regeneration: "border-ink-700 bg-ink-900/60 text-ink-300",
  Grundlage: "border-sky-900/60 bg-sky-950/30 text-sky-200",
  Tempo: "border-amber-900/60 bg-amber-950/30 text-amber-200",
  Schwelle: "border-orange-900/60 bg-orange-950/30 text-orange-200",
  Intervalle: "border-red-900/60 bg-red-950/30 text-red-200",
  Longrun: "border-emerald-900/60 bg-emerald-950/30 text-emerald-200",
  Kraft: "border-violet-900/60 bg-violet-950/30 text-violet-200",
  Wettkampf: "border-brand-light/50 bg-brand/15 text-orange-200",
  Test: "border-ink-700 bg-ink-900/60 text-ink-300",
  Sonstiges: "border-ink-700 bg-ink-900/60 text-ink-300",
};

type FormState = {
  goal: string;
  targetDate: string;
  weeks: number;
  sessionsPerWeek: number;
  hoursPerWeek: number;
  primarySport: string;
  constraints: string;
};

export function PlanBuilder({
  initial,
  defaults,
  disabled,
}: {
  initial: TrainingPlan | null;
  defaults: { sessionsPerWeek: number; hoursPerWeek: number; primarySport: string; goal: string };
  disabled: boolean;
}) {
  const [form, setForm] = useState<FormState>({
    goal: defaults.goal,
    targetDate: "",
    weeks: 8,
    sessionsPerWeek: defaults.sessionsPerWeek,
    hoursPerWeek: defaults.hoursPerWeek,
    primarySport: defaults.primarySport,
    constraints: "",
  });
  const [plan, setPlan] = useState(initial);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError(null);

    try {
      const response = await fetch("/api/ai/plan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...form, targetDate: form.targetDate || null }),
      });
      const data = (await response.json()) as { plan?: TrainingPlan; error?: string };
      if (!response.ok || !data.plan) {
        setError(data.error ?? "Der Plan konnte nicht erstellt werden.");
        return;
      }
      setPlan(data.plan);
    } catch {
      setError("Die Verbindung wurde unterbrochen. Bitte erneut versuchen.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <Card title="Was ist dein Ziel?">
        <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
          <Field label="Ziel" className="sm:col-span-2">
            <input
              required
              value={form.goal}
              onChange={(e) => setForm({ ...form, goal: e.target.value })}
              placeholder="z. B. Halbmarathon unter 1:35 h"
              className={inputClass}
            />
          </Field>

          <Field label="Zieldatum (optional)">
            <input
              type="date"
              value={form.targetDate}
              onChange={(e) => setForm({ ...form, targetDate: e.target.value })}
              className={inputClass}
            />
          </Field>

          <Field label="Hauptsportart">
            <select
              value={form.primarySport}
              onChange={(e) => setForm({ ...form, primarySport: e.target.value })}
              className={inputClass}
            >
              {["Laufen", "Radfahren", "Triathlon", "Schwimmen", "Trailrunning"].map((sport) => (
                <option key={sport} value={sport}>
                  {sport}
                </option>
              ))}
            </select>
          </Field>

          <Field label={`Dauer: ${form.weeks} Wochen`}>
            <input
              type="range"
              min={2}
              max={20}
              value={form.weeks}
              onChange={(e) => setForm({ ...form, weeks: Number(e.target.value) })}
              className="w-full accent-[#3fc3dc]"
            />
          </Field>

          <Field label={`Einheiten pro Woche: ${form.sessionsPerWeek}`}>
            <input
              type="range"
              min={2}
              max={12}
              value={form.sessionsPerWeek}
              onChange={(e) => setForm({ ...form, sessionsPerWeek: Number(e.target.value) })}
              className="w-full accent-[#3fc3dc]"
            />
          </Field>

          <Field label={`Stunden pro Woche: ${form.hoursPerWeek}`}>
            <input
              type="range"
              min={1}
              max={20}
              step={0.5}
              value={form.hoursPerWeek}
              onChange={(e) => setForm({ ...form, hoursPerWeek: Number(e.target.value) })}
              className="w-full accent-[#3fc3dc]"
            />
          </Field>

          <Field label="Randbedingungen (optional)" className="sm:col-span-2">
            <textarea
              rows={3}
              value={form.constraints}
              onChange={(e) => setForm({ ...form, constraints: e.target.value })}
              placeholder="z. B. dienstags kein Training, alte Achillessehnen-Verletzung, kein Zugang zur Bahn"
              className={inputClass}
            />
          </Field>

          <div className="sm:col-span-2">
            <button
              type="submit"
              disabled={busy || disabled}
              className="rounded-lg bg-brand px-5 py-2.5 font-medium text-white transition hover:bg-brand-dark disabled:cursor-not-allowed disabled:opacity-50"
            >
              {busy ? "Claude schreibt den Plan …" : "Trainingsplan erstellen"}
            </button>
            {busy && (
              <p className="mt-2 text-xs text-ink-500">
                Ein {form.weeks}-Wochen-Plan dauert ein bis drei Minuten. Fenster offen lassen.
              </p>
            )}
          </div>
        </form>
      </Card>

      {disabled && (
        <p className="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200">
          Für die Planerstellung wird ein ANTHROPIC_API_KEY benötigt.
        </p>
      )}

      {error && (
        <p className="rounded-xl border border-red-800/60 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          {error}
        </p>
      )}

      {plan && <PlanView plan={plan} />}
    </div>
  );
}

function PlanView({ plan }: { plan: TrainingPlan }) {
  return (
    <div className="space-y-6">
      <Card>
        <h2 className="text-xl font-semibold text-ink-100">{plan.title}</h2>
        <p className="mt-3 leading-relaxed text-ink-300">{plan.summary}</p>

        <dl className="mt-5 grid gap-4 border-t border-ink-800 pt-5 sm:grid-cols-2">
          <Detail term="Trainingsprinzip">{plan.philosophy}</Detail>
          <Detail term="Ausgangspunkt">{plan.startingPoint}</Detail>
          <Detail term="Wochenaufbau">{plan.weeklyStructure}</Detail>
          <Detail term="Progression">{plan.progressionNotes}</Detail>
        </dl>

        {plan.keyWorkouts.length > 0 && (
          <div className="mt-5 border-t border-ink-800 pt-5">
            <h3 className="text-sm font-medium text-ink-100">Schlüsseleinheiten</h3>
            <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-ink-300">
              {plan.keyWorkouts.map((workout) => (
                <li key={workout}>{workout}</li>
              ))}
            </ul>
          </div>
        )}

        {plan.warnings.length > 0 && (
          <div className="mt-5 rounded-xl border border-amber-800/60 bg-amber-950/30 px-4 py-3">
            <h3 className="text-sm font-medium text-amber-200">Darauf musst du achten</h3>
            <ul className="mt-2 list-inside list-disc space-y-1 text-sm text-amber-100/80">
              {plan.warnings.map((warning) => (
                <li key={warning}>{warning}</li>
              ))}
            </ul>
          </div>
        )}
      </Card>

      {plan.weeks.map((week) => (
        <WeekCard key={`${week.weekNumber}-${week.startDate}`} week={week} />
      ))}
    </div>
  );
}

function WeekCard({ week }: { week: PlanWeek }) {
  const [open, setOpen] = useState(week.weekNumber === 1);

  return (
    <Card>
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        className="flex w-full flex-wrap items-center justify-between gap-3 text-left"
      >
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="font-semibold text-ink-100">
              Woche {week.weekNumber} · ab {week.startDate}
            </h3>
            {week.isRecoveryWeek && <Badge tone="gut">Entlastung</Badge>}
          </div>
          <p className="mt-1 text-sm text-ink-300">{week.focus}</p>
        </div>
        <div className="flex items-center gap-4 text-sm tabular-nums text-ink-500">
          <span>{week.targetHours} h</span>
          <span>{week.targetLoad} Punkte</span>
          <span className="text-ink-300">{open ? "▲" : "▼"}</span>
        </div>
      </button>

      {open && (
        <>
          {week.notes && <p className="mt-4 text-sm leading-relaxed text-ink-300">{week.notes}</p>}
          <ul className="mt-4 space-y-2">
            {week.sessions.map((session, index) => (
              <li
                key={`${session.date}-${index}`}
                className={`rounded-xl border px-4 py-3 ${SESSION_TONE[session.type] ?? SESSION_TONE.Sonstiges}`}
              >
                <div className="flex flex-wrap items-baseline justify-between gap-2">
                  <div className="flex flex-wrap items-baseline gap-2">
                    <span className="text-xs uppercase tracking-wide opacity-70">
                      {session.weekday} · {session.date}
                    </span>
                    <span className="font-medium">{session.title}</span>
                  </div>
                  <span className="text-xs tabular-nums opacity-80">
                    {session.durationMin > 0 && `${session.durationMin} min · `}
                    {session.targetIntensity}
                  </span>
                </div>
                {session.description && (
                  <p className="mt-1.5 text-sm leading-relaxed opacity-90">{session.description}</p>
                )}
              </li>
            ))}
          </ul>
        </>
      )}
    </Card>
  );
}

function Field({
  label,
  children,
  className = "",
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1.5 block text-sm text-ink-300">{label}</span>
      {children}
    </label>
  );
}

function Detail({ term, children }: { term: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-xs uppercase tracking-wide text-ink-500">{term}</dt>
      <dd className="mt-1 text-sm leading-relaxed text-ink-300">{children}</dd>
    </div>
  );
}

const inputClass =
  "w-full rounded-lg border border-ink-700 bg-ink-900 px-3 py-2 text-ink-100 outline-none transition focus:border-brand-light";
