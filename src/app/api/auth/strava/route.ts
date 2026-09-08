import { randomBytes } from "node:crypto";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { StravaNotConfiguredError, authorizeUrl } from "@/lib/strava";

/** Startet den Strava-OAuth-Flow. */
export async function GET() {
  try {
    // CSRF-Schutz: der state-Wert muss im Callback unveraendert zurueckkommen.
    const state = randomBytes(16).toString("hex");
    const store = await cookies();
    store.set("pacer_oauth_state", state, {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 600,
    });

    return NextResponse.redirect(authorizeUrl(state));
  } catch (error) {
    if (error instanceof StravaNotConfiguredError) {
      return NextResponse.redirect(
        new URL("/?error=strava_nicht_konfiguriert", process.env.APP_URL ?? "http://localhost:3000"),
      );
    }
    throw error;
  }
}
