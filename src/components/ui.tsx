import type { ReactNode } from "react";

export function Card({
  title,
  subtitle,
  action,
  children,
  className = "",
}: {
  title?: string;
  subtitle?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`rounded-2xl border border-ink-800 bg-ink-850/70 p-5 shadow-sm ${className}`}
    >
      {(title || action) && (
        <header className="mb-4 flex flex-wrap items-start justify-between gap-3">
          <div>
            {title && <h2 className="text-base font-semibold text-ink-100">{title}</h2>}
            {subtitle && <p className="mt-0.5 text-sm text-ink-500">{subtitle}</p>}
          </div>
          {action}
        </header>
      )}
      {children}
    </section>
  );
}

/**
 * Kennzahl mit Einordnung. Die Zahl traegt die Aussage, das Label steht
 * darueber - der Farbpunkt daneben verbindet sie mit der Kurve.
 */
export function StatTile({
  label,
  value,
  unit,
  hint,
  accent,
}: {
  label: string;
  value: string | number;
  unit?: string;
  hint?: string;
  accent?: string;
}) {
  return (
    <div className="rounded-xl border border-ink-800 bg-ink-900/60 px-4 py-3.5">
      <div className="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-ink-500">
        {accent && (
          <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: accent }} />
        )}
        {/* Lange Bezeichnungen muessen in schmalen Kacheln umbrechen duerfen. */}
        <span className="min-w-0 break-words">{label}</span>
      </div>
      <div className="mt-1.5 flex items-baseline gap-1">
        <span className="text-2xl font-semibold tabular-nums text-ink-100">{value}</span>
        {unit && <span className="text-sm text-ink-500">{unit}</span>}
      </div>
      {hint && <p className="mt-1 text-xs leading-snug text-ink-500">{hint}</p>}
    </div>
  );
}

export function Badge({
  children,
  tone = "neutral",
}: {
  children: ReactNode;
  tone?: "neutral" | "gut" | "warnung" | "kritisch";
}) {
  const tones = {
    neutral: "border-ink-700 bg-ink-800 text-ink-300",
    gut: "border-emerald-800/60 bg-emerald-950/50 text-emerald-300",
    warnung: "border-amber-800/60 bg-amber-950/50 text-amber-300",
    kritisch: "border-red-800/60 bg-red-950/50 text-red-300",
  };
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium ${tones[tone]}`}
    >
      {children}
    </span>
  );
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="rounded-2xl border border-dashed border-ink-700 px-6 py-12 text-center">
      <h3 className="text-base font-medium text-ink-100">{title}</h3>
      {children && <div className="mx-auto mt-2 max-w-md text-sm text-ink-500">{children}</div>}
    </div>
  );
}
