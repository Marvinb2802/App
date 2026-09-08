"use client";

import { useState } from "react";
import type { WeekSummary } from "@/lib/metrics";

const BAR_COLOR = "#3987e5";

function formatWeek(iso: string): string {
  const [, month, day] = iso.split("-");
  return `${day}.${month}.`;
}

/**
 * Wochenumfang als Balken. Eine Reihe, eine Achse - der Umfang in Stunden.
 * Die Belastungspunkte stehen im Tooltip und in der Tabelle darunter.
 */
export function WeeklyVolume({ weeks }: { weeks: WeekSummary[] }) {
  const [hover, setHover] = useState<number | null>(null);
  const [showTable, setShowTable] = useState(false);

  const max = Math.max(1, ...weeks.map((w) => w.hours));

  return (
    <figure className="m-0">
      <figcaption className="mb-3 flex flex-wrap items-baseline justify-between gap-2">
        <span className="text-sm font-medium text-ink-100">Wochenumfang</span>
        <button
          type="button"
          onClick={() => setShowTable((value) => !value)}
          className="text-xs text-ink-500 underline underline-offset-2 transition hover:text-ink-300"
        >
          {showTable ? "Diagramm zeigen" : "Als Tabelle zeigen"}
        </button>
      </figcaption>

      {showTable ? (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="text-ink-500">
              <tr>
                <th className="py-1.5 pr-4 font-medium">Woche ab</th>
                <th className="py-1.5 pr-4 font-medium">Einheiten</th>
                <th className="py-1.5 pr-4 font-medium">Stunden</th>
                <th className="py-1.5 pr-4 font-medium">km</th>
                <th className="py-1.5 pr-4 font-medium">Hm</th>
                <th className="py-1.5 font-medium">Belastung</th>
              </tr>
            </thead>
            <tbody className="tabular-nums">
              {[...weeks].reverse().map((week) => (
                <tr key={week.weekStart} className="border-t border-ink-800">
                  <td className="py-1.5 pr-4 text-ink-300">{week.weekStart}</td>
                  <td className="py-1.5 pr-4">{week.sessions}</td>
                  <td className="py-1.5 pr-4">{week.hours}</td>
                  <td className="py-1.5 pr-4">{week.distanceKm}</td>
                  <td className="py-1.5 pr-4">{week.elevationM}</td>
                  <td className="py-1.5">{week.load}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="relative">
          <div className="flex h-44 items-end gap-[2px]">
            {weeks.map((week, index) => (
              <button
                key={week.weekStart}
                type="button"
                onFocus={() => setHover(index)}
                onBlur={() => setHover(null)}
                onPointerEnter={() => setHover(index)}
                onPointerLeave={() => setHover(null)}
                className="group relative flex h-full flex-1 cursor-default items-end"
                aria-label={`Woche ab ${week.weekStart}: ${week.hours} Stunden, ${week.sessions} Einheiten`}
              >
                <span
                  className="w-full rounded-t transition-opacity"
                  style={{
                    height: `${Math.max(2, (week.hours / max) * 100)}%`,
                    background: BAR_COLOR,
                    opacity: hover === null || hover === index ? 1 : 0.45,
                  }}
                />
              </button>
            ))}
          </div>

          <div className="mt-2 flex justify-between text-xs text-ink-500">
            <span>{formatWeek(weeks[0]?.weekStart ?? "")}</span>
            <span>Stunden pro Woche</span>
            <span>{formatWeek(weeks.at(-1)?.weekStart ?? "")}</span>
          </div>

          {hover !== null && (
            <div className="pointer-events-none absolute left-0 top-0 rounded-lg border border-ink-700 bg-ink-900/95 px-3 py-2 text-xs shadow-lg">
              <div className="font-medium text-ink-100">Woche ab {weeks[hover].weekStart}</div>
              <div className="mt-1 space-y-0.5 tabular-nums text-ink-300">
                <div>{weeks[hover].hours} h · {weeks[hover].sessions} Einheiten</div>
                <div>{weeks[hover].distanceKm} km · {weeks[hover].elevationM} Hm</div>
                <div>Belastung {weeks[hover].load} · Monotonie {weeks[hover].monotony}</div>
              </div>
            </div>
          )}
        </div>
      )}
    </figure>
  );
}
