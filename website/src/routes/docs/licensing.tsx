import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { LINX } from "../../lib/linx";
import {
  LIFETIME_PRICE_USD,
  YEARLY_PRICE_USD,
} from "../../lib/pricing";

export default function LicensingDocs() {
  return (
    <article class="prose">
      <Title>Licensing & subscriptions — InstaLay</Title>
      <h1>Licensing and subscriptions</h1>
      <p class="lede">
        InstaLay Free is the full app. Paid plans support the developer. Web
        purchases and ownership live on{" "}
        <a href={LINX.home} rel="noopener noreferrer">
          Linx Photos
        </a>
        ; mobile store builds can also use Adapty access levels.
      </p>

      <h2>Plans</h2>
      <ul>
        <li>
          <strong>Yearly</strong> — ${YEARLY_PRICE_USD.toFixed(0)} / year
        </li>
        <li>
          <strong>Lifetime</strong> — ${LIFETIME_PRICE_USD.toFixed(0)} once
        </li>
      </ul>
      <p>
        See <A href="/docs/pricing">pricing</A>. Checkout:{" "}
        <a href={LINX.instalayBuy} rel="noopener noreferrer">
          linx.photos/apps/instalay
        </a>
        .
      </p>

      <h2>Linx Photos entitlement</h2>
      <p>
        Sign in on Linx, purchase yearly or lifetime, then view status under{" "}
        <a href={LINX.instalayAccount} rel="noopener noreferrer">
          Account → InstaLay
        </a>
        . Fulfillment mints an <code>IL-XXXX-XXXX-XXXX-XXXX</code> key you can
        paste in the desktop license dialog.
      </p>
      <p>
        <a class="btn btn-ghost" href={LINX.login} rel="noopener noreferrer">
          Log in to view your license
        </a>
      </p>

      <h2>Mobile: Adapty (optional)</h2>
      <p>
        On iOS/Android store builds,{" "}
        <a href="https://adapty.io/">Adapty</a> can still answer store IAP
        access (level <code>instalay</code>). Web ownership on Linx does not
        require Adapty for desktop.
      </p>
    </article>
  );
}
