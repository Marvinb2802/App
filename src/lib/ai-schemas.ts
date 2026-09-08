import { z } from "zod";

/* Schemata fuer die strukturierten Antworten des Modells. Sie sind zugleich
 * Vertrag gegenueber der API (JSON-Schema) und Laufzeitvalidierung. */

export const AnalysisSchema = z.object({
  headline: z.string().describe("Ein Satz, der den aktuellen Trainingszustand auf den Punkt bringt"),
  formAssessment: z
    .string()
    .describe("2-4 Saetze zur aktuellen Form: Fitness, Ermuedung, Frische und was das praktisch heisst"),
  score: z.number().describe("Gesamtbewertung des Trainings der letzten 4 Wochen von 0 bis 100"),
  strengths: z
    .array(z.object({ title: z.string(), detail: z.string() }))
    .describe("Was der Athlet gut macht, mit konkretem Bezug auf die Daten"),
  risks: z
    .array(
      z.object({
        title: z.string(),
        detail: z.string(),
        // .catch(): Ein unerwarteter Wert soll die gesamte Antwort nicht verwerfen.
        severity: z.enum(["niedrig", "mittel", "hoch"]).catch("mittel"),
      }),
    )
    .describe("Risiken wie zu schnelle Belastungssteigerung, zu wenig Regeneration, Intensitaetsverteilung"),
  recommendations: z
    .array(
      z.object({
        title: z.string(),
        detail: z.string(),
        priority: z.enum(["hoch", "mittel", "niedrig"]).catch("mittel"),
        timeframe: z.string().describe("z. B. 'diese Woche' oder 'naechste 4 Wochen'"),
      }),
    )
    .describe("Konkrete, umsetzbare Empfehlungen"),
  nextWeekFocus: z.string().describe("Der eine Schwerpunkt fuer die kommende Woche"),
  dataGaps: z
    .array(z.string())
    .describe("Fehlende Daten, die die Analyse unsicher machen (z. B. keine Herzfrequenz)"),
});

export type Analysis = z.infer<typeof AnalysisSchema>;

export const PlanSessionSchema = z.object({
  date: z.string().describe("ISO-Datum YYYY-MM-DD"),
  weekday: z.string().describe("Wochentag auf Deutsch, z. B. Montag"),
  type: z
    .enum([
      "Ruhetag",
      "Regeneration",
      "Grundlage",
      "Tempo",
      "Schwelle",
      "Intervalle",
      "Longrun",
      "Kraft",
      "Wettkampf",
      "Test",
      "Sonstiges",
    ])
    // Die API traegt die Auswahl nur als Beschreibung weiter, erzwingt sie also
    // nicht. Ein abweichender Wert landet neutral bei "Sonstiges", statt den
    // ganzen Plan ungueltig zu machen.
    .catch("Sonstiges")
    .describe("Art der Einheit"),
  title: z.string().describe("Kurzer Titel der Einheit"),
  description: z.string().describe("Ablauf der Einheit inklusive Aufwaermen und Ausfahren"),
  durationMin: z.number().describe("Geplante Dauer in Minuten, 0 bei Ruhetag"),
  targetIntensity: z
    .string()
    .describe("Zielbereich, z. B. 'HF Zone 2' oder 'Schwellentempo' oder '-' bei Ruhetag"),
  estimatedLoad: z.number().describe("Geschaetzte Trainingsbelastung in Punkten, 0 bei Ruhetag"),
});

export const PlanWeekSchema = z.object({
  weekNumber: z.number(),
  startDate: z.string().describe("Montag dieser Woche als ISO-Datum"),
  focus: z.string().describe("Schwerpunkt der Woche"),
  isRecoveryWeek: z.boolean(),
  targetHours: z.number(),
  targetLoad: z.number(),
  notes: z.string(),
  sessions: z.array(PlanSessionSchema).describe("Genau sieben Eintraege, Montag bis Sonntag"),
});

export const PlanSchema = z.object({
  title: z.string(),
  summary: z.string().describe("3-5 Saetze: Aufbaulogik des Plans und warum er zum Athleten passt"),
  philosophy: z.string().describe("Trainingsprinzip, dem der Plan folgt"),
  startingPoint: z.string().describe("Von welchem Ausgangsniveau der Plan ausgeht"),
  weeklyStructure: z.string().describe("Wie eine typische Woche aufgebaut ist"),
  weeks: z.array(PlanWeekSchema),
  keyWorkouts: z.array(z.string()).describe("Die Schluesseleinheiten des Plans"),
  progressionNotes: z.string().describe("Wie sich Umfang und Intensitaet ueber den Plan entwickeln"),
  warnings: z.array(z.string()).describe("Worauf der Athlet achten muss, Abbruchkriterien"),
});

export type TrainingPlan = z.infer<typeof PlanSchema>;
export type PlanWeek = z.infer<typeof PlanWeekSchema>;
export type PlanSession = z.infer<typeof PlanSessionSchema>;
