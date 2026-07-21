import { defineConfig } from "@solidjs/start/config";

// Project Pages URL: https://linxphotos.github.io/InstaLay/
// Must match the GitHub repo name (case-sensitive on Pages asset paths).
// When instalay.linx.photos DNS is ready, switch GITHUB_PAGES_BASE to "/" and add CNAME.
const base = process.env.GITHUB_PAGES_BASE || "/InstaLay/";

export default defineConfig({
  vite: {
    base,
  },
  server: {
    preset: "static",
    baseURL: base,
    prerender: {
      crawlLinks: true,
      routes: [
        "/",
        "/docs",
        "/docs/pricing",
        "/docs/install",
        "/docs/licensing",
        "/buy",
        "/buy/success",
        "/download",
      ],
    },
  },
});
