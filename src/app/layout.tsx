import type { Metadata, Viewport } from "next";
import Link from "next/link";
import { isDatabaseConfigured } from "@/lib/db";
import { getCurrentAthlete } from "@/lib/session";
import { LogoutButton } from "@/components/LogoutButton";
import { MobileNav } from "@/components/MobileNav";
import "./globals.css";

export const metadata: Metadata = {
  title: "Pacer",
  description:
    "Pacer liest dein Ausdauertraining, erklaert dir deine Form und schreibt dir einen Trainingsplan, der zu deinem tatsaechlichen Niveau passt.",
  applicationName: "Pacer",
  // Startet vom Home-Bildschirm ohne Browser-Leiste, mit dunkler Statusleiste.
  appleWebApp: {
    capable: true,
    title: "Pacer",
    statusBarStyle: "black-translucent",
  },
  icons: {
    icon: [{ url: "/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple: [{ url: "/icon-180.png", sizes: "180x180", type: "image/png" }],
  },
  other: {
    // Next setzt nur den standardisierten Namen. Aeltere iOS-Versionen
    // brauchen zusaetzlich Apples eigenen, sonst bleibt die Browser-Leiste.
    "apple-mobile-web-app-capable": "yes",
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0c10",
  // viewport-fit deckt bei Geraeten mit Aussparung auch die Raender ab.
  viewportFit: "cover",
  width: "device-width",
  initialScale: 1,
};

const NAV = [
  { href: "/", label: "Übersicht" },
  { href: "/analyse", label: "KI-Analyse" },
  { href: "/plan", label: "Trainingsplan" },
  { href: "/coach", label: "Coach-Chat" },
  { href: "/einstellungen", label: "Einstellungen" },
];

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Ohne Datenbank zeigt die Startseite die Einrichtung - die Kopfzeile bleibt leer.
  const athlete = isDatabaseConfigured() ? await getCurrentAthlete() : null;
  const name = [athlete?.firstname, athlete?.lastname].filter(Boolean).join(" ");

  return (
    <html lang="de">
      <body className="font-sans antialiased">
        <header
          className="sticky top-0 z-20 border-b border-ink-800/80 bg-ink-950/85 backdrop-blur"
          style={{ paddingTop: "env(safe-area-inset-top)" }}
        >
          <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-5 py-3">
            <Link href="/" className="flex items-center gap-2.5 font-semibold tracking-tight">
              <span className="grid h-8 w-8 place-items-center rounded-lg bg-brand text-sm font-bold text-white">
                P
              </span>
              <span>Pacer</span>
            </Link>

            {athlete && (
              <nav className="hidden flex-wrap items-center gap-1 text-sm sm:flex">
                {NAV.map((item) => (
                  <Link
                    key={item.href}
                    href={item.href}
                    className="rounded-md px-3 py-1.5 text-ink-300 transition hover:bg-ink-800 hover:text-ink-100"
                  >
                    {item.label}
                  </Link>
                ))}
              </nav>
            )}

            {athlete && (
              <div className="ml-auto flex items-center gap-3 text-sm text-ink-300">
                <span className="hidden sm:inline">{name || `Athlet ${athlete.id}`}</span>
                <LogoutButton />
              </div>
            )}
          </div>
        </header>

        <main className="mx-auto w-full max-w-6xl px-5 py-8">{children}</main>

        {athlete && <MobileNav />}

        <footer className="mx-auto max-w-6xl space-y-2 px-5 pb-28 pt-4 text-xs leading-relaxed text-ink-500 sm:pb-10">
          <p>
            Trainingsempfehlungen ohne medizinische Prüfung. Bei Schmerzen, anhaltender Erschöpfung
            oder Krankheit gehört die Entscheidung zu einer Ärztin oder einem Arzt, nicht zu dieser App.
          </p>
          {/* Von den Strava-Markenrichtlinien vorgeschrieben, sobald Strava-Daten angezeigt werden. */}
          <p>Aktivitätsdaten powered by Strava. Pacer ist ein eigenständiges Angebot und gehört nicht zu Strava.</p>
        </footer>
      </body>
    </html>
  );
}
