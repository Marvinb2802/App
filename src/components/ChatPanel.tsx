"use client";

import { useEffect, useRef, useState } from "react";

type Message = { role: "user" | "assistant"; content: string };

const SUGGESTIONS = [
  "Wie ist meine Form gerade wirklich?",
  "Trainiere ich zu viel im mittleren Bereich?",
  "Wie sollte meine nächste Woche aussehen?",
  "Bin ich bereit für einen harten Longrun?",
];

export function ChatPanel({ history, disabled }: { history: Message[]; disabled: boolean }) {
  const [messages, setMessages] = useState<Message[]>(history);
  const [input, setInput] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [messages]);

  async function send(text: string) {
    const question = text.trim();
    if (!question || busy) return;

    setInput("");
    setError(null);
    setBusy(true);
    setMessages((current) => [...current, { role: "user", content: question }, { role: "assistant", content: "" }]);

    try {
      const response = await fetch("/api/ai/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: question }),
      });

      if (!response.ok || !response.body) {
        const data = (await response.json().catch(() => ({}))) as { error?: string };
        setError(data.error ?? "Die Antwort konnte nicht geladen werden.");
        setMessages((current) => current.slice(0, -1));
        return;
      }

      // Antwort zeichenweise in die letzte Nachricht schreiben.
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let answer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        answer += decoder.decode(value, { stream: true });
        setMessages((current) => [...current.slice(0, -1), { role: "assistant", content: answer }]);
      }
    } catch {
      setError("Die Verbindung wurde unterbrochen.");
      setMessages((current) => current.slice(0, -1));
    } finally {
      setBusy(false);
    }
  }

  async function clearHistory() {
    await fetch("/api/ai/chat", { method: "DELETE" });
    setMessages([]);
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="min-h-[45vh] space-y-4 rounded-2xl border border-ink-800 bg-ink-850/70 p-5">
        {messages.length === 0 && (
          <div className="py-8 text-center">
            <p className="text-sm text-ink-500">
              Frag deinen Coach etwas. Er kennt deine Aktivitäten der letzten Monate.
            </p>
            <div className="mt-5 flex flex-wrap justify-center gap-2">
              {SUGGESTIONS.map((suggestion) => (
                <button
                  key={suggestion}
                  type="button"
                  disabled={disabled}
                  onClick={() => send(suggestion)}
                  className="rounded-full border border-ink-700 px-3.5 py-1.5 text-sm text-ink-300 transition hover:bg-ink-800 disabled:opacity-40"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((message, index) => (
          <div
            key={index}
            className={message.role === "user" ? "flex justify-end" : "flex justify-start"}
          >
            <div
              className={
                message.role === "user"
                  ? "max-w-[85%] rounded-2xl rounded-br-sm bg-brand px-4 py-2.5 text-white"
                  : "max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-bl-sm border border-ink-700 bg-ink-900 px-4 py-2.5 leading-relaxed text-ink-100"
              }
            >
              {message.content || (
                <span className="inline-flex gap-1 text-ink-500">
                  <span className="animate-pulse">●</span> denkt nach
                </span>
              )}
            </div>
          </div>
        ))}
        <div ref={endRef} />
      </div>

      {error && (
        <p className="rounded-xl border border-red-800/60 bg-red-950/40 px-4 py-3 text-sm text-red-200">
          {error}
        </p>
      )}

      <form
        onSubmit={(event) => {
          event.preventDefault();
          send(input);
        }}
        className="flex gap-3"
      >
        <input
          value={input}
          onChange={(event) => setInput(event.target.value)}
          disabled={disabled || busy}
          placeholder={disabled ? "ANTHROPIC_API_KEY fehlt" : "Deine Frage …"}
          className="flex-1 rounded-lg border border-ink-700 bg-ink-900 px-4 py-3 text-ink-100 outline-none transition focus:border-brand-light disabled:opacity-50"
        />
        <button
          type="submit"
          disabled={disabled || busy || input.trim().length === 0}
          className="rounded-lg bg-brand px-5 py-3 font-medium text-white transition hover:bg-brand-dark disabled:cursor-not-allowed disabled:opacity-50"
        >
          Senden
        </button>
      </form>

      {messages.length > 0 && (
        <button
          type="button"
          onClick={clearHistory}
          className="self-start text-xs text-ink-500 underline underline-offset-2 transition hover:text-ink-300"
        >
          Verlauf löschen
        </button>
      )}
    </div>
  );
}
