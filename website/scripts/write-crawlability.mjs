import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { writeFileSync } from "node:fs";
import { getBasePath, getSitemapRoutes, SITE_ORIGIN } from "./site-routes.mjs";

function escapeXml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function normalizeBase(base) {
  if (!base || base === "/") return "";
  return base.replace(/\/$/, "");
}

function absoluteUrl(path) {
  const origin = SITE_ORIGIN.replace(/\/$/, "");
  const base = normalizeBase(getBasePath());
  if (!path || path === "/") return `${origin}${base}/`;
  const suffix = path.startsWith("/") ? path : `/${path}`;
  return `${origin}${base}${suffix}`;
}

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pub = join(root, ".output", "public");
const locs = [...new Set(getSitemapRoutes().map(absoluteUrl))];
const body = locs.map((loc) => `  <url><loc>${escapeXml(loc)}</loc></url>`).join("\n");
const sitemapLoc = absoluteUrl("/sitemap.xml");

writeFileSync(
  join(pub, "sitemap.xml"),
  `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${body}\n</urlset>\n`,
);
writeFileSync(
  join(pub, "robots.txt"),
  `User-agent: *\nAllow: /\n\nSitemap: ${sitemapLoc}\n`,
);
console.log(`Wrote robots.txt + sitemap.xml (${locs.length} URLs) → .output/public/`);
