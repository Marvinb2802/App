"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/** Ein Symbol je Bereich - schlichte Striche, damit sie klein lesbar bleiben. */
const ICONS: Record<string, React.ReactNode> = {
  "/": (
    <path d="M3 13.5 10 6l4 4 7-7" strokeLinecap="round" strokeLinejoin="round" />
  ),
  "/analyse": (
    <>
      <path d="M4 20V10M10 20V4M16 20v-7M22 20h-20" strokeLinecap="round" />
    </>
  ),
  "/plan": (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2" />
      <path d="M3 10h18M8 3v4M16 3v4" strokeLinecap="round" />
    </>
  ),
  "/coach": (
    <path
      d="M20 15a3 3 0 0 1-3 3H8l-4 3V6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3z"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  ),
  "/einstellungen": (
    <>
      <circle cx="12" cy="12" r="3" />
      <path
        d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M19.1 4.9 17 7M7 17l-2.1 2.1"
        strokeLinecap="round"
      />
    </>
  ),
};

const ITEMS = [
  { href: "/", label: "Übersicht" },
  { href: "/analyse", label: "Analyse" },
  { href: "/plan", label: "Plan" },
  { href: "/coach", label: "Coach" },
  { href: "/einstellungen", label: "Mehr" },
];

/**
 * Die Navigationsleiste am unteren Rand - auf dem Handy der Unterschied
 * zwischen "Website im Browser" und "App". Ab Tablet-Breite verschwindet sie
 * zugunsten der Leiste in der Kopfzeile.
 */
export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav
      className="fixed inset-x-0 bottom-0 z-30 border-t border-ink-800 bg-ink-950/95 backdrop-blur sm:hidden"
      style={{ paddingBottom: "env(safe-area-inset-bottom)" }}
      aria-label="Hauptnavigation"
    >
      <ul className="flex">
        {ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <li key={item.href} className="flex-1">
              <Link
                href={item.href}
                aria-current={active ? "page" : undefined}
                className={`flex flex-col items-center gap-1 py-2.5 text-[11px] transition ${
                  active ? "text-brand-light" : "text-ink-500"
                }`}
              >
                <svg
                  width="22"
                  height="22"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  aria-hidden="true"
                >
                  {ICONS[item.href]}
                </svg>
                {item.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
