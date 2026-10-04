import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { BuyButton } from "../../components/BuyButton";
import { LINX, linxInstalayBuyUrl } from "../../lib/linx";
import {
  EDITIONS,
  LICENSE_PLANS,
  LIFETIME_PRICE_USD,
  YEARLY_PRICE_USD,
} from "../../lib/pricing";

/**
 * Canonical storefront for the InstaLay static site.
 * Checkout and entitlement live on linx.photos (`/apps/instalay`).
 */
export default function PricingDocs() {
  return (
    <article class="prose">
      <Title>Pricing — InstaLay</Title>
      <h1>Pricing</h1>
      <p class="lede">
        Two names, one app. {EDITIONS.paid.summary} Checkout and license status
        live on{" "}
        <a href={LINX.home} rel="noopener noreferrer">
          Linx Photos
        </a>
        .
      </p>

      <div class="plan-grid">
        <div class="plan">
          <h2>{EDITIONS.free.name}</h2>
          <p class="price-hero">$0</p>
          <p>{EDITIONS.free.summary}</p>
          <A class="btn btn-ghost" href="/download">
            Download Free
          </A>
        </div>
        <div class="plan">
          <h2>{EDITIONS.paid.name}</h2>
          <p class="price-hero">
            ${YEARLY_PRICE_USD.toFixed(0)}
            <span class="price-hero-unit">/yr</span>
            {" · "}
            ${LIFETIME_PRICE_USD.toFixed(0)}
          </p>
          <p>{EDITIONS.paid.summary}</p>
          <div class="cta-row">
            <BuyButton plan="yearly" />
            <BuyButton plan="lifetime" />
          </div>
        </div>
      </div>

      <h2>Plans</h2>
      <ul>
        <li>
          <strong>Yearly</strong> — ${YEARLY_PRICE_USD.toFixed(0)} /{" "}
          {LICENSE_PLANS.yearly.intervalLabel}. Billed on Linx Photos (Stripe).
        </li>
        <li>
          <strong>Lifetime</strong> — ${LIFETIME_PRICE_USD.toFixed(0)} one-time.
          Permanent license on your Linx account.
        </li>
      </ul>
      <p>
        <a class="btn btn-primary" href={linxInstalayBuyUrl()} rel="noopener noreferrer">
          Continue to Linx Photos checkout
        </a>{" "}
        <a class="btn btn-ghost" href={LINX.login} rel="noopener noreferrer">
          Log in to view your license
        </a>
      </p>

      <h2>What a license covers</h2>
      <ul>
        <li>Windows (win32 + Microsoft Store MSIX)</li>
        <li>macOS (Homebrew cask + DMG)</li>
        <li>Linux portable</li>
        <li>Android / iOS store builds</li>
        <li>Web build</li>
      </ul>
      <p>
        After payment, ownership appears under{" "}
        <a href={LINX.instalayAccount} rel="noopener noreferrer">
          Linx Photos → Account → InstaLay
        </a>
        . Desktop builds can also use the emailed <code>IL-····</code> key.
      </p>

      <p class="muted">
        The lifetime price is set so it still covers costs after the highest app-store fee.
        The store-by-store numbers are on the{" "}
        <A href="/docs/marketplace-margin">marketplace margin</A> page.
      </p>

    </article>
  );
}
