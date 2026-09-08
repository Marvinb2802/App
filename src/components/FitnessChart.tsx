"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { FitnessPoint } from "@/lib/metrics";

const SERIES = [
  { key: "ctl", label: "Fitness", color: "#3987e5", hint: "42-Tage-Mittel der Belastung" },
  { key: "atl", label: "Ermüdung", color: "#d95926", hint: "7-Tage-Mittel der Belastung" },
  { key: "tsb", label: "Form", color: "#199e70", hint: "Fitness minus Ermüdung" },
] as const;

const WIDE = { width: 860, height: 260, days: 180 };
const NARROW = { width: 420, height: 260, days: 90 };
const PAD = { top: 16, right: 56, bottom: 26, left: 40 };

/** Erkennt Handybreite, damit das Diagramm dort nicht flachgedrueckt wird. */
function useNarrowScreen(): boolean {
  const [narrow, setNarrow] = useState(false);

  useEffect(() => {
    const query = window.matchMedia("(max-width: 640px)");
    const update = () => setNarrow(query.matches);
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);

  return narrow;
}

/**
 * Fitness, Ermuedung und Form auf einer gemeinsamen Achse - alle drei Reihen
 * teilen sich die Einheit "Belastungspunkte pro Tag", darum genau eine y-Achse.
 */
export function FitnessChart({ points }: { points: FitnessPoint[] }) {
  const svgRef = useRef<SVGSVGElement>(null);
  const [hoverIndex, setHoverIndex] = useState<number | null>(null);
  const narrow = useNarrowScreen();
  const { width: WIDTH, height: HEIGHT, days } = narrow ? NARROW : WIDE;

  const data = useMemo(() => points.slice(-days), [points, days]);

  const scales = useMemo(() => {
    const values = data.flatMap((p) => [p.ctl, p.atl, p.tsb]);
    const min = Math.min(0, ...values);
    const max = Math.max(10, ...values);
    const span = max - min || 1;

    const x = (index: number) =>
      PAD.left + (index / Math.max(1, data.length - 1)) * (WIDTH - PAD.left - PAD.right);
    const y = (value: number) =>
      PAD.top + (1 - (value - min) / span) * (HEIGHT - PAD.top - PAD.bottom);

    return { x, y, min, max };
  }, [data, WIDTH, HEIGHT]);

  if (data.length < 2) {
    return (
      <p className="py-10 text-center text-sm text-ink-500">
        Noch zu wenig Historie für eine Verlaufskurve.
      </p>
    );
  }

  const path = (key: "ctl" | "atl" | "tsb") =>
    data.map((p, i) => `${i === 0 ? "M" : "L"}${scales.x(i).toFixed(1)},${scales.y(p[key]).toFixed(1)}`).join(" ");

  const gridValues = [scales.min, (scales.min + scales.max) / 2, scales.max].map((v) => Math.round(v));
  const active = hoverIndex !== null ? data[hoverIndex] : null;
  const last = data[data.length - 1];

  function handleMove(event: React.PointerEvent<SVGSVGElement>) {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) return;
    const relative = ((event.clientX - rect.left) / rect.width) * WIDTH;
    const ratio = (relative - PAD.left) / (WIDTH - PAD.left - PAD.right);
    const index = Math.round(ratio * (data.length - 1));
    setHoverIndex(Math.min(data.length - 1, Math.max(0, index)));
  }

  return (
    <figure className="m-0">
      <figcaption className="mb-3 flex flex-wrap items-baseline gap-x-4 gap-y-1">
        <span className="text-sm font-medium text-ink-100">Fitness, Ermüdung und Form</span>
        <span className="text-xs text-ink-500">
          letzte {data.length} Tage · Belastungspunkte
        </span>
      </figcaption>

      <div className="relative">
        <svg
          ref={svgRef}
          viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
          className="w-full touch-none"
          role="img"
          aria-label="Verlauf von Fitness, Ermüdung und Form"
          onPointerMove={handleMove}
          onPointerLeave={() => setHoverIndex(null)}
        >
          {gridValues.map((value) => (
            <g key={value}>
              <line
                x1={PAD.left}
                x2={WIDTH - PAD.right}
                y1={scales.y(value)}
                y2={scales.y(value)}
                stroke="#2a3040"
                strokeWidth={1}
              />
              <text x={PAD.left - 8} y={scales.y(value) + 4} textAnchor="end" fontSize={11} fill="#6b7488">
                {value}
              </text>
            </g>
          ))}

          {scales.min < 0 && (
            <line
              x1={PAD.left}
              x2={WIDTH - PAD.right}
              y1={scales.y(0)}
              y2={scales.y(0)}
              stroke="#4b5468"
              strokeWidth={1}
              strokeDasharray="3 3"
            />
          )}

          {SERIES.map((series) => (
            <path
              key={series.key}
              d={path(series.key)}
              fill="none"
              stroke={series.color}
              strokeWidth={2}
              strokeLinejoin="round"
              strokeLinecap="round"
            />
          ))}

          {/* Direkte Beschriftung am letzten Punkt statt Werten auf jedem Punkt. */}
          {SERIES.map((series) => (
            <text
              key={`label-${series.key}`}
              x={WIDTH - PAD.right + 8}
              y={scales.y(last[series.key]) + 4}
              fontSize={11}
              fill={series.color}
              fontWeight={600}
            >
              {Math.round(last[series.key])}
            </text>
          ))}

          {active && hoverIndex !== null && (
            <g>
              <line
                x1={scales.x(hoverIndex)}
                x2={scales.x(hoverIndex)}
                y1={PAD.top}
                y2={HEIGHT - PAD.bottom}
                stroke="#6b7488"
                strokeWidth={1}
              />
              {SERIES.map((series) => (
                <circle
                  key={`dot-${series.key}`}
                  cx={scales.x(hoverIndex)}
                  cy={scales.y(active[series.key])}
                  r={4.5}
                  fill={series.color}
                  stroke="#151922"
                  strokeWidth={2}
                />
              ))}
            </g>
          )}

          <text x={PAD.left} y={HEIGHT - 6} fontSize={11} fill="#6b7488">
            {data[0].date}
          </text>
          <text x={WIDTH - PAD.right} y={HEIGHT - 6} fontSize={11} fill="#6b7488" textAnchor="end">
            {last.date}
          </text>
        </svg>

        {active && (
          <div className="pointer-events-none absolute left-3 top-3 rounded-lg border border-ink-700 bg-ink-900/95 px-3 py-2 text-xs shadow-lg">
            <div className="mb-1 font-medium text-ink-100">{active.date}</div>
            {SERIES.map((series) => (
              <div key={series.key} className="flex items-center gap-2 text-ink-300">
                <span className="h-2 w-2 rounded-full" style={{ background: series.color }} />
                <span className="w-20">{series.label}</span>
                <span className="tabular-nums text-ink-100">{active[series.key].toFixed(1)}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-xs text-ink-300">
        {SERIES.map((series) => (
          <span key={series.key} className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-sm" style={{ background: series.color }} />
            {series.label}
            <span className="text-ink-500">({series.hint})</span>
          </span>
        ))}
      </div>
    </figure>
  );
}
