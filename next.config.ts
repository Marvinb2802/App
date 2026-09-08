import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Datenbanktreiber werden zur Laufzeit geladen, nicht mitgebuendelt.
  serverExternalPackages: ["pg", "@electric-sql/pglite"],
};

export default nextConfig;
