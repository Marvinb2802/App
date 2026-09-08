import { NextResponse } from "next/server";
import { analyzeTraining } from "@/lib/ai";
import { errorResponse } from "@/lib/api";
import { execute } from "@/lib/db";
import { requireAthlete } from "@/lib/session";
import { loadSnapshot } from "@/lib/snapshot";

export const maxDuration = 60;

/** Erzeugt eine neue KI-Analyse und legt sie im Verlauf ab. */
export async function POST() {
  try {
    const athlete = await requireAthlete();
    const snapshot = await loadSnapshot(athlete);

    if (snapshot.activityCount === 0) {
      return NextResponse.json(
        { error: "Es sind noch keine Aktivitaeten vorhanden. Synchronisiere zuerst mit Strava." },
        { status: 400 },
      );
    }

    const analysis = await analyzeTraining(athlete, snapshot);

    await execute(
      "INSERT INTO ai_reports (athlete_id, kind, payload) VALUES ($1, 'analysis', $2)",
      [athlete.id, JSON.stringify(analysis)],
    );

    return NextResponse.json({ analysis });
  } catch (error) {
    return errorResponse(error);
  }
}
