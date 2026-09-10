import { defineConfig } from "@solidjs/start/config";
import { getBasePath, getPrerenderRoutes } from "./scripts/site-routes.mjs";

// Custom domain: https://instalay.linx.photos/ (CNAME in public/).
// CI may set GITHUB_PAGES_BASE for project-pages previews.
const base = getBasePath();

export default defineConfig({
  vite: {
    base,
  },
  server: {
    preset: "static",
    baseURL: base,
    prerender: {
      crawlLinks: true,
      routes: getPrerenderRoutes(),
    },
  },
});
