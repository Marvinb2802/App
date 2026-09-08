import type Anthropic from "@anthropic-ai/sdk";
import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";
import { chatSystemPrompt, streamChat } from "@/lib/ai";
import { errorResponse } from "@/lib/api";
import { getDb } from "@/lib/db";
import { requireAthlete } from "@/lib/session";
import { loadSnapshot } from "@/lib/snapshot";

export const maxDuration = 300;

const RequestSchema = z.object({ message: z.string().min(1).max(4000) });

/** Coach-Chat: streamt die Antwort als reinen Text zum Browser. */
export async function POST(request: NextRequest) {
  try {
    const athlete = await requireAthlete();
    const { message } = RequestSchema.parse(await request.json());
    const db = getDb();

    // Die letzten Runden als Gespraechsverlauf, aelteste zuerst.
    const history = db
      .prepare(
        `SELECT role, content FROM chat_messages
          WHERE athlete_id = ? ORDER BY id DESC LIMIT 20`,
      )
      .all(athlete.id) as { role: "user" | "assistant"; content: string }[];

    const messages: Anthropic.MessageParam[] = history
      .reverse()
      .map((row) => ({ role: row.role, content: row.content }));
    messages.push({ role: "user", content: message });

    db.prepare("INSERT INTO chat_messages (athlete_id, role, content) VALUES (?, 'user', ?)").run(
      athlete.id,
      message,
    );

    const snapshot = loadSnapshot(athlete);
    const stream = streamChat(chatSystemPrompt(athlete, snapshot), messages);

    const body = new ReadableStream<Uint8Array>({
      async start(controller) {
        const encoder = new TextEncoder();
        let answer = "";
        try {
          for await (const event of stream) {
            if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
              answer += event.delta.text;
              controller.enqueue(encoder.encode(event.delta.text));
            }
          }
          db.prepare(
            "INSERT INTO chat_messages (athlete_id, role, content) VALUES (?, 'assistant', ?)",
          ).run(athlete.id, answer);
        } catch (streamError) {
          const text =
            streamError instanceof Error ? streamError.message : "Verbindung abgebrochen.";
          controller.enqueue(encoder.encode(`\n\n[Fehler: ${text}]`));
        } finally {
          controller.close();
        }
      },
    });

    return new Response(body, {
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Accel-Buffering": "no",
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ error: "Die Nachricht ist leer oder zu lang." }, { status: 400 });
    }
    return errorResponse(error);
  }
}

/** Verlauf loeschen. */
export async function DELETE() {
  try {
    const athlete = await requireAthlete();
    getDb().prepare("DELETE FROM chat_messages WHERE athlete_id = ?").run(athlete.id);
    return NextResponse.json({ ok: true });
  } catch (error) {
    return errorResponse(error);
  }
}
