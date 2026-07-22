export type Theme = "light" | "dark";

export function systemTheme(): Theme {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

export function applyTheme(theme: Theme): void {
  const root = document.documentElement;
  root.dataset.theme = theme;
  root.style.colorScheme = theme;
}

export function readAppliedTheme(): Theme {
  const raw = document.documentElement.dataset.theme;
  if (raw === "dark" || raw === "light") return raw;
  return systemTheme();
}

/** Inline bootstrap for `<head>` — apply system theme before paint. */
export const THEME_BOOTSTRAP = `(function(){try{var t=matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light";var r=document.documentElement;r.dataset.theme=t;r.style.colorScheme=t;}catch(e){}})();`;
