import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";
import { generatePlan } from "@/lib/ai";
import { errorResponse } from "@/lib/api";
import { queryOne } from "@/lib/db";
import { requireAthlete } from "@/lib/session";
import { loadSnapshot } from "@/lib/snapshot";

// 60 Sekunden ist das Limit der kostenlosen Vercel-Stufe. Wer laengere Plaene
// erzeugen will, setzt den Wert hoch (bis 300) und braucht einen bezahlten Plan.
export const maxDuration = 60;

const RequestSchema = z.object({
  goal: z.string().min(3).max(300),
  targetDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  weeks: z.number().int().min(2).max(20),
  sessionsPerWeek: z.number().int().min(2).max(14),
  hoursPerWeek: z.number().min(1).max(30),
  primarySport: z.string().min(2).max(50),
  constraints: z.string().max(1000),
});

/** Laesst Claude einen Trainingsplan auf Basis der echten Daten schreiben. */
export async function POST(request: NextRequest) {
  try {
    const athlete = await requireAthlete();
    const input = RequestSchema.parse(await request.json());
    const snapshot = await loadSnapshot(athlete);

    if (snapshot.activityCount === 0) {
      return NextResponse.json(
        { error: "Ohne Trainingshistorie laesst sich kein sinnvoller Plan erstellen." },
        { status: 400 },
      );
    }

    const plan = await generatePlan(athlete, snapshot, input);

    const created = await queryOne<{ id: number }>(
      `INSERT INTO plans (athlete_id, goal, target_date, weeks, payload)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [athlete.id, input.goal, input.targetDate, input.weeks, JSON.stringify(plan)],
    );

    return NextResponse.json({ plan, id: created?.id ?? null });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: `Ungueltige Eingabe: ${error.issues.map((i) => i.message).join("; ")}` },
        { status: 400 },
      );
    }
    return errorResponse(error);
  }
}
