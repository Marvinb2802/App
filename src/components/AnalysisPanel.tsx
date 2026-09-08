"use client";

import { useState } from "react";
import type { Analysis } from "@/lib/ai-schemas";
import { Badge, Card } from "@/components/ui";

const SEVERITY_TONE = { hoch: "kritisch", mittel: "warnung", niedrig: "neutral" } as const;
const PRIORITY_TONE = { hoch: "kritisch", mittel: "warnung", niedrig: "neutral" } as const;

export function AnalysisPanel({
  initial,
  createdAt,
  disabled,
}: {
  initial: Analysis | null;
  createdAt: string | null;
  disabled: boolean;
}) {
  const [analysis, setAnalysis] = useState(initial);
  const [stamp, setStamp] = useState(createdAt);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run() {
    setBusy(true);
    setError(null);
    try {
      const response = await fetch("/api/ai/analysis", { method: "POST" });
      const data = (await response.json()) as { analysis?: Analysis; error?: string };
      if (!response.ok || !data.analysis) {
        setError(data.error ?? "Die Analyse konnte nicht erstellt werden.");
        return;
      }
      setAnalysis(data.analysis);
      setStamp(new Date().toISOString().slice(0, 16).replace("T", " "));
    } catch {
      setError("Die Verbindung wurde unterbrochen. Bitte erneut versuchen.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-ink-500">
          {stamp ? `Letzte Analyse: ${stamp}` : "Noch keine Analyse erstellt."}
        </p>
        <button
          type="button"
          onClick={run}
          disabled={busy || disabled}
          className="rounded-lg bg-brand px-5 py-2.5 font-medium text-white transition hover:bg-brand-dark disabled:cursor-not-allowed disabled:opacity-50"
        >
          {busy ? "Claude analysiert …" : analysis ? "Neu analysieren" : "Training analysieren"}
        </button>
      </div>

      {disabled && (
        <p className="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200">
          Für die Analyse wird ein ANTHROPIC_API_KEY benötigt.
        </p>
      )}

      {error && (
        <p className="rounded-xl border border-red-800/60 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          {error}
        </p>
      )}

      {busy && !analysis && (
        <div className="rounded-2xl border border-ink-800 bg-ink-850/70 p-8 text-center text-sm text-ink-500">
          Claude liest deine letzten Wochen. Das dauert meist eine halbe bis eine Minute.
        </div>
      )}

      {analysis && (
        <div className="space-y-6">
          <Card>
            <div className="flex flex-wrap items-start justify-between gap-5">
              <div className="max-w-2xl">
                <h2 className="text-xl font-semibold leading-snug text-ink-100">
                  {analysis.headline}
                </h2>
                <p className="mt-3 leading-relaxed text-ink-300">{analysis.formAssessment}</p>
              </div>
              <div className="rounded-xl border border-ink-700 bg-ink-900/60 px-5 py-4 text-center">
                <div className="text-3xl font-semibold tabular-nums text-ink-100">
                  {Math.round(analysis.score)}
                </div>
                <div className="mt-1 text-xs uppercase tracking-wide text-ink-500">von 100</div>
              </div>
            </div>
          </Card>

          <Card title="Fokus für die kommende Woche">
            <p className="leading-relaxed text-ink-100">{analysis.nextWeekFocus}</p>
          </Card>

          <div className="grid gap-6 lg:grid-cols-2">
            <Card title="Das läuft gut">
              <ul className="space-y-4">
                {analysis.strengths.map((item) => (
                  <li key={item.title}>
                    <p className="font-medium text-ink-100">{item.title}</p>
                    <p className="mt-1 text-sm leading-relaxed text-ink-300">{item.detail}</p>
                  </li>
                ))}
              </ul>
            </Card>

            <Card title="Risiken">
              <ul className="space-y-4">
                {analysis.risks.map((item) => (
                  <li key={item.title}>
                    <div className="flex flex-wrap items-center gap-2">
                      <p className="font-medium text-ink-100">{item.title}</p>
                      <Badge tone={SEVERITY_TONE[item.severity]}>{item.severity}</Badge>
                    </div>
                    <p className="mt-1 text-sm leading-relaxed text-ink-300">{item.detail}</p>
                  </li>
                ))}
              </ul>
            </Card>
          </div>

          <Card title="Empfehlungen">
            <ul className="space-y-5">
              {analysis.recommendations.map((item) => (
                <li key={item.title} className="border-l-2 border-brand-light/50 pl-4">
                  <div className="flex flex-wrap items-center gap-2">
                    <p className="font-medium text-ink-100">{item.title}</p>
                    <Badge tone={PRIORITY_TONE[item.priority]}>Priorität {item.priority}</Badge>
                    <span className="text-xs text-ink-500">{item.timeframe}</span>
                  </div>
                  <p className="mt-1.5 text-sm leading-relaxed text-ink-300">{item.detail}</p>
                </li>
              ))}
            </ul>
          </Card>

          {analysis.dataGaps.length > 0 && (
            <Card title="Was die Analyse unsicher macht">
              <ul className="list-inside list-disc space-y-1 text-sm text-ink-300">
                {analysis.dataGaps.map((gap) => (
                  <li key={gap}>{gap}</li>
                ))}
              </ul>
            </Card>
          )}
        </div>
      )}
    </div>
  );
}
