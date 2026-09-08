import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { setSession } from "@/lib/session";
import {
  appUrl,
  exchangeCodeForTokens,
  saveTokens,
  syncActivities,
  syncAthleteZones,
  upsertAthlete,
} from "@/lib/strava";

function back(path: string): NextResponse {
  return NextResponse.redirect(new URL(path, appUrl()));
}

/** Callback von Strava: Code gegen Tokens tauschen und erste Daten holen. */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;

  if (params.get("error")) {
    return back(`/?error=${encodeURIComponent(params.get("error") ?? "zugriff_verweigert")}`);
  }

  const code = params.get("code");
  const state = params.get("state");
  const store = await cookies();
  const expectedState = store.get("pacer_oauth_state")?.value;
  store.delete("pacer_oauth_state");

  if (!code) return back("/?error=kein_code");
  if (!state || state !== expectedState) return back("/?error=ungueltiger_state");

  // Ohne activity:read_all sieht die App nur einen Teil der Aktivitaeten.
  const scope = params.get("scope") ?? "";
  if (!scope.includes("activity:read")) return back("/?error=fehlende_berechtigung");

  const tokens = await exchangeCodeForTokens(code);
  if (!tokens.athlete) return back("/?error=kein_athlet");

  upsertAthlete(tokens.athlete);
  saveTokens(tokens.athlete.id, tokens);
  await setSession(tokens.athlete.id);

  try {
    await syncAthleteZones(tokens.athlete.id);
    await syncActivities(tokens.athlete.id);
  } catch {
    // Der erste Sync darf den Login nicht blockieren - er ist manuell wiederholbar.
    return back("/?warnung=sync_unvollstaendig");
  }

  return back("/");
}
