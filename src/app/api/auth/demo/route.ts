import { NextResponse } from "next/server";
import { errorResponse } from "@/lib/api";
import { DEMO_ATHLETE_ID, seedDemoData } from "@/lib/demo";
import { setSession } from "@/lib/session";

/** Meldet den Demo-Athleten an und legt bei Bedarf seine Trainingshistorie an. */
export async function POST() {
  try {
    await seedDemoData();
    await setSession(DEMO_ATHLETE_ID);
    return NextResponse.json({ ok: true });
  } catch (error) {
    return errorResponse(error);
  }
}
