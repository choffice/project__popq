import path from "node:path";
import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const rootEnv = loadEnv(mode, path.resolve(__dirname, "../.."), "");
  const tossClientKey =
    process.env.VITE_POPQ_TOSS_CLIENT_KEY ?? rootEnv.POPQ_TOSS_CLIENT_KEY ?? "";

  return {
    plugins: [react()],
    define: {
      "import.meta.env.VITE_POPQ_TOSS_CLIENT_KEY":
        JSON.stringify(tossClientKey),
    },
    server: {
      host: true,
      proxy: {
        "/api": {
          target: "http://localhost:8082",
          changeOrigin: true,
        },
        "/ws": {
          target: "ws://localhost:8082",
          ws: true,
        },
      },
    },
    test: {
      environment: "jsdom",
      setupFiles: "./src/test/setup.ts",
    },
  };
});
