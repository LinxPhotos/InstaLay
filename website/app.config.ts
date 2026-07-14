import { defineConfig } from "@solidjs/start/config";

const base = process.env.GITHUB_PAGES_BASE || "/insta-lay/";

export default defineConfig({
  // Project site: https://amdphreak.github.io/insta-lay/
  vite: {
    base,
  },
  server: {
    preset: "static",
    baseURL: base,
    prerender: {
      crawlLinks: true,
      routes: ["/", "/docs", "/docs/pricing", "/docs/install", "/buy", "/buy/success", "/download"],
    },
  },
});
