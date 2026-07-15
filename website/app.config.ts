import { defineConfig } from "@solidjs/start/config";

// Custom domain app.linx.photos → site is served at the domain apex (base "/").
// Override with GITHUB_PAGES_BASE only when publishing under a path prefix.
const base = process.env.GITHUB_PAGES_BASE || "/";

export default defineConfig({
  // https://app.linx.photos  (also https://linxphotos.github.io/insta-lay/ while DNS settles)
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
