import { NextResponse } from "next/server";
import { DEMO_ATHLETE_ID, seedDemoData } from "@/lib/demo";
import { setSession } from "@/lib/session";

/** Meldet den Demo-Athleten an und legt bei Bedarf seine Trainingshistorie an. */
export async function POST() {
  seedDemoData();
  await setSession(DEMO_ATHLETE_ID);
  return NextResponse.json({ ok: true });
}
