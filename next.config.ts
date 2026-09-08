import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Der Postgres-Treiber wird zur Laufzeit geladen, nicht mitgebuendelt.
  serverExternalPackages: ["pg"],
};

export default nextConfig;
