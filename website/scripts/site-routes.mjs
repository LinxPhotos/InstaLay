/**
 * Canonical indexable routes for InstaLay marketing site.
 * Exclude API and checkout success (transactional).
 */
export const SITE_ORIGIN = "https://instalay.linx.photos";

/** Prefer custom domain (CNAME). Override with GITHUB_PAGES_BASE for project-pages previews. */
export function getBasePath() {
  const raw = process.env.GITHUB_PAGES_BASE;
  if (raw == null || raw === "") return "/";
  return raw.endsWith("/") ? raw : `${raw}/`;
}

const STATIC_ROUTES = [
  "/",
  "/docs",
  "/docs/pricing",
  "/docs/install",
  "/docs/licensing",
  "/buy",
  "/buy/success",
  "/download",
];

export function getPrerenderRoutes() {
  return [...STATIC_ROUTES];
}

/** Paths excluded from sitemap (still may be prerendered). */
export function getSitemapRoutes() {
  return getPrerenderRoutes().filter((r) => r !== "/buy/success");
}
