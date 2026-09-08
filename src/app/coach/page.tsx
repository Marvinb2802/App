import { redirect } from "next/navigation";
import { ChatPanel } from "@/components/ChatPanel";
import { isAiConfigured } from "@/lib/ai";
import { getDb } from "@/lib/db";
import { getCurrentAthlete } from "@/lib/session";

export const dynamic = "force-dynamic";

export default async function CoachPage() {
  const athlete = await getCurrentAthlete();
  if (!athlete) redirect("/");

  const history = getDb()
    .prepare(
      `SELECT role, content FROM chat_messages
        WHERE athlete_id = ? ORDER BY id ASC LIMIT 60`,
    )
    .all(athlete.id) as { role: "user" | "assistant"; content: string }[];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Coach-Chat</h1>
        <p className="mt-1 max-w-2xl text-sm text-ink-500">
          Jede Antwort entsteht mit deinem aktuellen Trainingsbild als Kontext – Belastungsverlauf,
          letzte Einheiten, Wochenumfänge.
        </p>
      </div>

      <ChatPanel history={history} disabled={!isAiConfigured()} />
    </div>
  );
}
