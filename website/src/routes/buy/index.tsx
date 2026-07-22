import { Title } from "@solidjs/meta";
import { Show } from "solid-js";
import { BuyButton } from "../../components/BuyButton";
import { PricingTable } from "../../components/PricingTable";
import { LINX } from "../../lib/linx";
import {
  EDITIONS,
  LICENSE_PLANS,
  LIFETIME_PRICE_USD,
  YEARLY_PRICE_USD,
} from "../../lib/pricing";
import { hasCheckoutConfigured, stripePaymentLink } from "../../lib/stripe";

export default function BuyPage() {
  const yearlyReady = () =>
    hasCheckoutConfigured("yearly") && Boolean(stripePaymentLink("yearly"));
  const lifetimeReady = () =>
    hasCheckoutConfigured("lifetime") && Boolean(stripePaymentLink("lifetime"));
  const anyReady = () => yearlyReady() || lifetimeReady();

  return (
    <article class="prose">
      <Title>Buy InstaLay</Title>
      <h1>Support the developer</h1>
      <p class="lede">
        {EDITIONS.paid.summary} Same features as {EDITIONS.free.name} — you’re
        paying so this keeps getting built.
      </p>

      <div class="plan-grid">
        <div class="plan">
          <h2>Yearly</h2>
          <p class="price-hero">${YEARLY_PRICE_USD.toFixed(0)}</p>
          <p class="muted">per year</p>
          <p>{LICENSE_PLANS.yearly.summary}</p>
          <BuyButton plan="yearly" label={`Pay $${YEARLY_PRICE_USD.toFixed(0)} / year`} />
        </div>
        <div class="plan">
          <h2>Lifetime</h2>
          <p class="price-hero">${LIFETIME_PRICE_USD.toFixed(0)}</p>
          <p class="muted">one-time</p>
          <p>{LICENSE_PLANS.lifetime.summary}</p>
          <BuyButton
            plan="lifetime"
            label={`Pay $${LIFETIME_PRICE_USD.toFixed(0)} — lifetime`}
          />
        </div>
      </div>

      <Show when={!anyReady()}>
        <div class="notice">
          <p>
            <strong>Checkout wiring:</strong> set{" "}
            <code>VITE_STRIPE_PAYMENT_LINK_YEARLY</code> and{" "}
            <code>VITE_STRIPE_PAYMENT_LINK_LIFETIME</code> to Stripe Payment
            Links for ${YEARLY_PRICE_USD.toFixed(0)}/year and $
            {LIFETIME_PRICE_USD.toFixed(0)} lifetime. Until then, this page
            documents the SKUs.
          </p>
          <p class="muted">
            For a full server checkout later, <code>POST /api/checkout</code>{" "}
            with <code>{`{ "plan": "yearly" | "lifetime" }`}</code> creates a
            Stripe Checkout Session (needs <code>STRIPE_SECRET_KEY</code> on a
            non-static host).
          </p>
        </div>
      </Show>

      <h2>InstaLay Free vs InstaLay</h2>
      <p>
        There is no feature gap. {EDITIONS.free.name} is the same app with a
        link to this page. {EDITIONS.paid.name} means you bought a license —
        thank you.
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
        After payment, Stripe emails a receipt. License fulfillment mints an{" "}
        <code>IL-····</code> key (see webhook helper) when entitlement checks
        are enabled.
      </p>

      <h2>Host &amp; publish with Linx Photos</h2>
      <p>
        InstaLay is the canvas.{" "}
        <a href={LINX.home} rel="noopener noreferrer">
          Linx Photos
        </a>{" "}
        is the library — private albums, share links, and social scheduling,
        with a deep-link bridge into InstaLay for tapestry edits.
      </p>
      <p>
        <a class="btn btn-ghost" href={LINX.home} rel="noopener noreferrer">
          Open Linx Photos
        </a>
      </p>

      <h2>Margin check (lifetime)</h2>
      <PricingTable />
    </article>
  );
}
