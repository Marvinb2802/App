import { NextResponse } from "next/server";
import { errorResponse } from "@/lib/api";
import { isDemoAthlete } from "@/lib/demo";
import { requireAthlete } from "@/lib/session";
import { syncActivities, syncAthleteZones } from "@/lib/strava";

export const maxDuration = 60;

/** Holt neue Aktivitaeten von Strava nach. */
export async function POST() {
  try {
    const athlete = await requireAthlete();

    if (isDemoAthlete(athlete.id)) {
      return NextResponse.json({
        ok: true,
        imported: 0,
        note: "Demo-Modus: Es gibt keine echte Strava-Verbindung zum Synchronisieren.",
      });
    }

    await syncAthleteZones(athlete.id);
    const { imported } = await syncActivities(athlete.id);
    return NextResponse.json({ ok: true, imported });
  } catch (error) {
    return errorResponse(error);
  }
}
