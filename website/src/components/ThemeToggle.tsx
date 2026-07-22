import { createSignal, onCleanup, onMount, Show } from "solid-js";
import {
  applyTheme,
  readAppliedTheme,
  systemTheme,
  type Theme,
} from "../lib/theme";

function SunIcon() {
  return (
    <svg
      class="theme-icon"
      viewBox="0 0 24 24"
      width="18"
      height="18"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2.5M12 19.5V22M4.93 4.93l1.77 1.77M17.3 17.3l1.77 1.77M2 12h2.5M19.5 12H22M4.93 19.07l1.77-1.77M17.3 6.7l1.77-1.77" />
    </svg>
  );
}

function MoonIcon() {
  return (
    <svg
      class="theme-icon"
      viewBox="0 0 24 24"
      width="18"
      height="18"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      stroke-width="1.75"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M20.5 14.2A8.2 8.2 0 0 1 9.8 3.5 8.5 8.5 0 1 0 20.5 14.2z" />
    </svg>
  );
}

/**
 * Light/dark toggle. Starts on the detected system theme. Clicking overrides
 * until the next `prefers-color-scheme` change, which clears the override.
 */
export function ThemeToggle() {
  const [theme, setTheme] = createSignal<Theme>("light");
  const [ready, setReady] = createSignal(false);

  onMount(() => {
    const initial = readAppliedTheme();
    setTheme(initial);
    applyTheme(initial);
    setReady(true);

    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    // Any OS theme change clears a manual override and re-follows system.
    const onSystemChange = () => {
      const next = systemTheme();
      setTheme(next);
      applyTheme(next);
    };
    mq.addEventListener("change", onSystemChange);
    onCleanup(() => mq.removeEventListener("change", onSystemChange));
  });

  const toggle = () => {
    const next: Theme = theme() === "dark" ? "light" : "dark";
    setTheme(next);
    applyTheme(next);
  };

  return (
    <button
      type="button"
      class="theme-toggle"
      onClick={toggle}
      aria-label={
        theme() === "dark" ? "Switch to light mode" : "Switch to dark mode"
      }
      title={theme() === "dark" ? "Light mode" : "Dark mode"}
    >
      <Show when={ready()}>
        <Show when={theme() === "dark"} fallback={<MoonIcon />}>
          <SunIcon />
        </Show>
      </Show>
    </button>
  );
}
