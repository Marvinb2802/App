import type { MetadataRoute } from "next";

/**
 * Macht Pacer auf dem Handy installierbar. Mit `display: "standalone"` startet
 * die App vom Home-Bildschirm ohne Browser-Leiste.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Pacer – Trainingsanalyse",
    short_name: "Pacer",
    description:
      "Pacer liest dein Ausdauertraining, erklärt dir deine Form und plant dein Training.",
    start_url: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#0a0c10",
    theme_color: "#0a0c10",
    lang: "de",
    categories: ["health", "fitness", "sports"],
    icons: [
      { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
  };
}
