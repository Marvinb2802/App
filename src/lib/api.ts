import { NextResponse } from "next/server";
import { AiNotConfiguredError } from "@/lib/ai";
import { DatabaseNotConfiguredError } from "@/lib/db";
import { UnauthorizedError } from "@/lib/session";
import { StravaApiError, StravaNotConfiguredError } from "@/lib/strava";
import Anthropic from "@anthropic-ai/sdk";

/** Uebersetzt bekannte Fehler in saubere HTTP-Antworten mit deutscher Meldung. */
export function errorResponse(error: unknown): NextResponse {
  if (error instanceof UnauthorizedError) {
    return NextResponse.json({ error: "Nicht angemeldet." }, { status: 401 });
  }
  if (
    error instanceof AiNotConfiguredError ||
    error instanceof StravaNotConfiguredError ||
    error instanceof DatabaseNotConfiguredError
  ) {
    return NextResponse.json({ error: error.message }, { status: 503 });
  }
  if (error instanceof StravaApiError) {
    return NextResponse.json({ error: error.message }, { status: error.status });
  }
  if (error instanceof Anthropic.RateLimitError) {
    return NextResponse.json(
      { error: "Anthropic-Rate-Limit erreicht. Bitte in einer Minute erneut versuchen." },
      { status: 429 },
    );
  }
  if (error instanceof Anthropic.AuthenticationError) {
    return NextResponse.json({ error: "Der ANTHROPIC_API_KEY ist ungueltig." }, { status: 401 });
  }
  if (error instanceof Anthropic.APIError) {
    return NextResponse.json(
      { error: `Fehler der Anthropic-API (${error.status}): ${error.message}` },
      { status: 502 },
    );
  }

  console.error("Unerwarteter Fehler:", error);
  return NextResponse.json(
    { error: error instanceof Error ? error.message : "Unerwarteter Fehler." },
    { status: 500 },
  );
}
