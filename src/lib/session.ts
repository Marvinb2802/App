import { createHmac, timingSafeEqual } from "node:crypto";
import { cookies } from "next/headers";
import { queryOne } from "@/lib/db";
import type { Athlete } from "@/lib/types";

const COOKIE_NAME = "pacer_session";
const MAX_AGE_SECONDS = 60 * 60 * 24 * 30; // 30 Tage

let warnedAboutSecret = false;

function secret(): string {
  const value = process.env.SESSION_SECRET;
  if (value) return value;

  // In Produktion ist ein fehlendes Geheimnis ein Fehler, keine Unbequemlichkeit.
  if (process.env.NODE_ENV === "production") {
    throw new Error("SESSION_SECRET fehlt. Lege sie in .env.local an (siehe .env.example).");
  }

  if (!warnedAboutSecret) {
    console.warn(
      "[session] SESSION_SECRET fehlt - es wird ein unsicherer Entwicklungswert verwendet.",
    );
    warnedAboutSecret = true;
  }
  return "entwicklung-unsicher";
}

function sign(value: string): string {
  return createHmac("sha256", secret()).update(value).digest("base64url");
}

/** Cookie-Wert: "<athleteId>.<HMAC>" */
function serialize(athleteId: number): string {
  const payload = String(athleteId);
  return `${payload}.${sign(payload)}`;
}

function deserialize(raw: string | undefined): number | null {
  if (!raw) return null;
  const sep = raw.lastIndexOf(".");
  if (sep <= 0) return null;

  const payload = raw.slice(0, sep);
  const provided = Buffer.from(raw.slice(sep + 1));
  const expected = Buffer.from(sign(payload));
  if (provided.length !== expected.length) return null;
  if (!timingSafeEqual(provided, expected)) return null;

  const id = Number.parseInt(payload, 10);
  return Number.isFinite(id) ? id : null;
}

export async function setSession(athleteId: number): Promise<void> {
  const store = await cookies();
  store.set(COOKIE_NAME, serialize(athleteId), {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: MAX_AGE_SECONDS,
  });
}

export async function clearSession(): Promise<void> {
  const store = await cookies();
  store.delete(COOKIE_NAME);
}

export async function getAthleteId(): Promise<number | null> {
  const store = await cookies();
  return deserialize(store.get(COOKIE_NAME)?.value);
}

/** Der eingeloggte Athlet, oder null wenn keine gueltige Session existiert. */
export async function getCurrentAthlete(): Promise<Athlete | null> {
  const id = await getAthleteId();
  if (id === null) return null;

  return queryOne<Athlete>("SELECT * FROM athletes WHERE id = $1", [id]);
}

/** Wie getCurrentAthlete, wirft aber statt null zurueckzugeben. Fuer API-Routen. */
export async function requireAthlete(): Promise<Athlete> {
  const athlete = await getCurrentAthlete();
  if (!athlete) throw new UnauthorizedError();
  return athlete;
}

export class UnauthorizedError extends Error {
  constructor() {
    super("Nicht angemeldet");
    this.name = "UnauthorizedError";
  }
}
