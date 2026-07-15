import { defineConfig } from "@solidjs/start/config";

// Project Pages URL: https://linxphotos.github.io/insta-lay/
// When instalay.linx.photos DNS is ready, switch GITHUB_PAGES_BASE to "/" and add CNAME.
const base = process.env.GITHUB_PAGES_BASE || "/insta-lay/";

export default defineConfig({
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
