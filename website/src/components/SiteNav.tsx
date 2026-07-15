import { A } from "@solidjs/router";

export function SiteNav() {
  return (
    <header class="nav">
      <A href="/" class="brand">
        InstaLay
      </A>
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
          <A href="/buy">Buy license</A>
        </li>
      </ul>
    </header>
  );
}
