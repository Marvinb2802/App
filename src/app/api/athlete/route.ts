import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";
import { errorResponse } from "@/lib/api";
import { getDb } from "@/lib/db";
import { requireAthlete } from "@/lib/session";

const SettingsSchema = z.object({
  weight_kg: z.number().min(30).max(200).nullable(),
  max_hr: z.number().int().min(120).max(230).nullable(),
  rest_hr: z.number().int().min(25).max(100).nullable(),
  threshold_hr: z.number().int().min(100).max(220).nullable(),
  ftp: z.number().int().min(50).max(600).nullable(),
  /** Schwellentempo Laufen in m/s (entspricht rund 2:23 bis 11:07 min/km) */
  threshold_pace: z.number().min(1.5).max(7).nullable(),
  goal: z.string().max(500).nullable(),
});

/** Speichert die Stammdaten, mit denen die Belastungsberechnung genauer wird. */
export async function POST(request: NextRequest) {
  try {
    const athlete = await requireAthlete();
    const settings = SettingsSchema.parse(await request.json());

    getDb()
      .prepare(
        `UPDATE athletes
            SET weight_kg = @weight_kg, max_hr = @max_hr, rest_hr = @rest_hr,
                threshold_hr = @threshold_hr, ftp = @ftp,
                threshold_pace = @threshold_pace, goal = @goal,
                updated_at = datetime('now')
          WHERE id = @id`,
      )
      .run({ ...settings, id: athlete.id });

    return NextResponse.json({ ok: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: `Ungueltige Eingabe: ${error.issues.map((i) => i.path.join(".")).join(", ")}` },
        { status: 400 },
      );
    }
    return errorResponse(error);
  }
}
