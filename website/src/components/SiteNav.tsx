import { A } from "@solidjs/router";
import { ThemeToggle } from "./ThemeToggle";

const logoSrc = `${import.meta.env.BASE_URL}instalay_logo.svg`.replace(
  /([^:]\/)\/+/g,
  "$1",
);

export function SiteNav() {
  return (
    <header class="nav">
      <A href="/" class="brand">
        <img
          src={logoSrc}
          alt=""
          width="28"
          height="28"
          class="brand-mark"
        />
        InstaLay
      </A>
      <div class="nav-end">
        <ul class="nav-links">
          <li>
            <A href="/docs">Docs</A>
          </li>
          <li>
            <A href="/docs/pricing">Pricing</A>
          </li>
          <li>
            <A href="/docs/install">Install</A>
          </li>
          <li>
            <A href="/download">Download</A>
          </li>
          <li>
            <A href="/buy">Buy InstaLay</A>
          </li>
        </ul>
        <ThemeToggle />
      </div>
    </header>
  );
}
