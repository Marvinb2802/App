import Anthropic from "@anthropic-ai/sdk";
import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import type { ZodType } from "zod";
import { AnalysisSchema, PlanSchema, type Analysis, type TrainingPlan } from "@/lib/ai-schemas";
import type { TrainingSnapshot } from "@/lib/metrics";
import type { Athlete } from "@/lib/types";

/** Claude Opus 5 denkt standardmaessig adaptiv - `thinking` bleibt daher ungesetzt. */
export const MODEL = "claude-opus-5";

export class AiNotConfiguredError extends Error {
  constructor() {
    super("ANTHROPIC_API_KEY fehlt. Ohne den Schluessel sind die KI-Funktionen deaktiviert.");
    this.name = "AiNotConfiguredError";
  }
}

export function isAiConfigured(): boolean {
  return Boolean(process.env.ANTHROPIC_API_KEY);
}

let client: Anthropic | null = null;

export function getClient(): Anthropic {
  if (!isAiConfigured()) throw new AiNotConfiguredError();
  if (!client) client = new Anthropic();
  return client;
}

/* -------------------------------------------------------------------------- */
/* Gemeinsamer Kontext                                                        */
/* -------------------------------------------------------------------------- */

/**
 * Der Teil des Prompts, der sich zwischen Anfragen nicht aendert. Er steht
 * bewusst vorne und wird gecacht - der variable Datenteil folgt dahinter.
 */
const COACH_ROLE = `Du bist ein erfahrener Ausdauertrainer mit sportwissenschaftlichem Hintergrund.
Du betreust Hobby- und ambitionierte Amateursportlerinnen und -sportler und arbeitest ausschliesslich
mit den Trainingsdaten, die dir vorgelegt werden.

Arbeitsweise:
- Du sprichst Deutsch, per Du, sachlich und direkt. Keine Motivationsfloskeln.
- Jede Aussage belegst du mit konkreten Zahlen aus den Daten. Erfinde niemals Werte.
- Die Belastungswerte sind TSS-aehnliche Punkte: eine Stunde an der anaeroben Schwelle = 100 Punkte.
  Fitness (CTL) ist das 42-Tage-Mittel der Tagesbelastung, Ermuedung (ATL) das 7-Tage-Mittel,
  Form (TSB) die Differenz. Ein ACWR-Wert (7 Tage zu 28-Tage-Wochenmittel) ueber 1.5 gilt als riskant,
  0.8 bis 1.3 als kontrolliert.
- Wenn die Datengrundlage duenn ist (wenige Einheiten, keine Herzfrequenz, geschaetzte Schwellenwerte),
  sagst du das offen, statt Praezision vorzutaeuschen.
- Du gibst Trainingsempfehlungen, keine medizinischen Diagnosen. Bei Anzeichen von Ueberlastung,
  Schmerz oder Krankheit verweist du auf aerztliche Abklaerung.
- Trainingsprinzipien, an die du dich haeltst: polarisierte oder pyramidale Intensitaetsverteilung
  (der Grossteil des Umfangs locker), Umfangssteigerung von hoechstens 5-10 Prozent pro Woche,
  alle drei bis vier Wochen eine Entlastungswoche, mindestens ein echter Ruhetag pro Woche.`;

function athleteBlock(athlete: Athlete, snapshot: TrainingSnapshot): string {
  const name = [athlete.firstname, athlete.lastname].filter(Boolean).join(" ") || "Unbekannt";
  const refs = snapshot.references;

  return `## Athlet
Name: ${name}
Geschlecht: ${athlete.sex ?? "unbekannt"}
Gewicht: ${athlete.weight_kg ? `${athlete.weight_kg} kg` : "unbekannt"}
Saisonziel: ${athlete.goal ?? "nicht angegeben"}

## Referenzwerte
Maximalherzfrequenz: ${refs.maxHr ?? "unbekannt"}
Schwellenherzfrequenz: ${refs.thresholdHr ?? "unbekannt"}
FTP: ${refs.ftp ? `${refs.ftp} W` : "unbekannt"}
Schwellentempo Laufen: ${refs.thresholdRunSpeed ? `${(1000 / refs.thresholdRunSpeed / 60).toFixed(2)} min/km` : "unbekannt"}
Geschaetzte Werte: ${refs.estimated.length > 0 ? refs.estimated.join("; ") : "keine"}

## Trainingsdaten (JSON)
Heutiges Datum: ${new Date().toISOString().slice(0, 10)}

\`\`\`json
${JSON.stringify(snapshot, null, 1)}
\`\`\``;
}

/* -------------------------------------------------------------------------- */
/* Strukturierte Antworten                                                    */
/* -------------------------------------------------------------------------- */

function extractText(content: Anthropic.Beta.BetaContentBlock[]): string {
  return content
    .filter((block): block is Anthropic.Beta.BetaTextBlock => block.type === "text")
    .map((block) => block.text)
    .join("\n");
}

/** Faengt Modellantworten ab, die das JSON in einen Markdown-Block gepackt haben. */
function parseJsonLoose<T>(raw: string, schema: ZodType<T>): T {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : raw.slice(raw.indexOf("{"), raw.lastIndexOf("}") + 1);
  return schema.parse(JSON.parse(candidate));
}

/**
 * Ruft das Modell mit erzwungenem Ausgabeformat auf. Liefert die API kein
 * geparstes Ergebnis (aeltere Route, Formatdrift), wird der Rohtext nachtraeglich
 * geparst, statt die Anfrage scheitern zu lassen.
 */
async function structuredCall<T>(params: {
  schema: ZodType<T>;
  system: string;
  prompt: string;
  maxTokens: number;
  effort: "low" | "medium" | "high";
}): Promise<T> {
  const stream = getClient().beta.messages.stream({
    model: MODEL,
    max_tokens: params.maxTokens,
    output_config: { effort: params.effort },
    output_format: betaZodOutputFormat(params.schema),
    system: [
      { type: "text", text: params.system, cache_control: { type: "ephemeral" } },
    ],
    messages: [{ role: "user", content: params.prompt }],
  });

  const message = await stream.finalMessage();

  if (message.stop_reason === "refusal") {
    throw new Error("Das Modell hat die Anfrage abgelehnt. Bitte formuliere sie anders.");
  }
  if (message.parsed_output) return message.parsed_output;

  return parseJsonLoose(extractText(message.content), params.schema);
}

/* -------------------------------------------------------------------------- */
/* Analyse                                                                    */
/* -------------------------------------------------------------------------- */

export async function analyzeTraining(
  athlete: Athlete,
  snapshot: TrainingSnapshot,
): Promise<Analysis> {
  return structuredCall({
    schema: AnalysisSchema,
    system: COACH_ROLE,
    maxTokens: 16000,
    effort: "high",
    prompt: `${athleteBlock(athlete, snapshot)}

## Aufgabe
Analysiere dieses Training. Beurteile:
1. Die aktuelle Form: Wie passen Fitness, Ermuedung und Frische zusammen und was folgt daraus?
2. Die Belastungsentwicklung der letzten acht Wochen - steigt sie kontrolliert oder zu schnell?
3. Die Intensitaetsverteilung - trainiert der Athlet zu viel im mittleren Bereich?
4. Regeneration: Ruhetage, Monotonie und Strain der letzten Wochen.
5. Die Konsistenz: Sind die Wochen gleichmaessig oder gibt es Ausreisser und Luecken?

Nenne bei jedem Punkt die Zahl, auf die du dich stuetzt. Die Empfehlungen muessen so konkret sein,
dass der Athlet sie morgen umsetzen kann.`,
  });
}

/* -------------------------------------------------------------------------- */
/* Trainingsplan                                                              */
/* -------------------------------------------------------------------------- */

export type PlanRequest = {
  goal: string;
  targetDate: string | null;
  weeks: number;
  sessionsPerWeek: number;
  hoursPerWeek: number;
  primarySport: string;
  constraints: string;
};

export async function generatePlan(
  athlete: Athlete,
  snapshot: TrainingSnapshot,
  request: PlanRequest,
): Promise<TrainingPlan> {
  const monday = nextMonday();

  return structuredCall({
    schema: PlanSchema,
    system: COACH_ROLE,
    maxTokens: 64000,
    effort: "high",
    prompt: `${athleteBlock(athlete, snapshot)}

## Auftrag
Erstelle einen Trainingsplan mit folgenden Vorgaben:
- Ziel: ${request.goal}
- Zieldatum: ${request.targetDate ?? "kein festes Datum"}
- Dauer: ${request.weeks} Wochen, beginnend am ${monday} (Montag)
- Hauptsportart: ${request.primarySport}
- Verfuegbar: ${request.sessionsPerWeek} Einheiten und rund ${request.hoursPerWeek} Stunden pro Woche
- Randbedingungen des Athleten: ${request.constraints || "keine angegeben"}

## Regeln
- Setze am tatsaechlichen Ausgangsniveau an: Die aktuelle Fitness (CTL ${snapshot.fitness.ctl}) und der
  Wochenumfang der letzten vier Wochen (${snapshot.last28Days.hours} h, ${snapshot.last28Days.sessions} Einheiten)
  sind die Basis. Springe nicht ueber das, was der Athlet zuletzt tatsaechlich trainiert hat.
- Steigere den Wochenumfang um hoechstens 5-10 Prozent und plane jede dritte oder vierte Woche als
  Entlastungswoche mit etwa 60-70 Prozent des Umfangs.
- Jede Woche enthaelt genau sieben Tage, Montag bis Sonntag, mit fortlaufenden Datumsangaben.
  Nicht genutzte Tage sind Ruhetage.
- Halte rund 80 Prozent des Umfangs im lockeren Bereich.
- Gibt es ein Zieldatum, plane die letzten ein bis zwei Wochen als Tapering.
- Beschreibe jede Einheit so, dass sie ohne Rueckfrage ausfuehrbar ist: Aufwaermen, Hauptteil mit
  Intervallen und Pausen, Ausfahren, Zielbereich in HF-Zonen oder Tempo.`,
  });
}

function nextMonday(): string {
  const date = new Date();
  const daysUntilMonday = (8 - date.getDay()) % 7 || 7;
  date.setDate(date.getDate() + daysUntilMonday);
  return date.toISOString().slice(0, 10);
}

/* -------------------------------------------------------------------------- */
/* Coach-Chat                                                                 */
/* -------------------------------------------------------------------------- */

export function chatSystemPrompt(athlete: Athlete, snapshot: TrainingSnapshot): string {
  return `${COACH_ROLE}

Du beantwortest jetzt Fragen des Athleten im Dialog. Antworte kurz und konkret - in der Regel
weniger als 200 Woerter, ohne Aufzaehlung wenn zwei Saetze reichen. Beziehe dich auf die Daten unten.

${athleteBlock(athlete, snapshot)}`;
}

export function streamChat(
  system: string,
  messages: Anthropic.MessageParam[],
): ReturnType<Anthropic["messages"]["stream"]> {
  return getClient().messages.stream({
    model: MODEL,
    max_tokens: 4000,
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    messages,
  });
}
