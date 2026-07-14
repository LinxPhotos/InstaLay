import { Title } from "@solidjs/meta";
import { Show } from "solid-js";
import { BuyButton } from "../components/BuyButton";
import { PricingTable } from "../components/PricingTable";
import { LICENSE_PRODUCT, LIST_PRICE_USD } from "../lib/pricing";
import { hasCheckoutConfigured, stripePaymentLink } from "../lib/stripe";

export default function BuyPage() {
  const link = () => stripePaymentLink();
  const configured = () => hasCheckoutConfigured() && Boolean(link());

  return (
    <article class="prose">
      <Title>Buy Insta Lay</Title>
      <h1>Own Insta Lay</h1>
      <p class="price-hero">${LIST_PRICE_USD.toFixed(2)}</p>
      <p>{LICENSE_PRODUCT.summary}</p>

      <Show
        when={configured()}
        fallback={
          <div class="notice">
            <p>
              <strong>Checkout wiring:</strong> set{" "}
              <code>VITE_STRIPE_PAYMENT_LINK</code> to your Stripe Payment Link
              for the ${LIST_PRICE_USD.toFixed(2)} lifetime product (created in
              Stripe Dashboard). Until then, this page documents the SKU and
              margin model.
            </p>
            <p class="muted">
              For a full server checkout later, <code>POST /api/checkout</code>{" "}
              creates a Stripe Checkout Session (needs{" "}
              <code>STRIPE_SECRET_KEY</code> on a non-static host).
            </p>
          </div>
        }
      >
        <BuyButton label={`Pay $${LIST_PRICE_USD.toFixed(2)} — lifetime`} />
      </Show>

      <h2>What “universal” means</h2>
      <ul>
        <li>Windows (win32 + Microsoft Store MSIX)</li>
        <li>macOS (Homebrew cask + DMG)</li>
        <li>Linux portable</li>
        <li>Android / iOS store builds</li>
        <li>Web build</li>
      </ul>
      <p>
        After payment, Stripe emails a receipt. License fulfillment mints an{" "}
        <code>IL-····</code> key (see webhook helper) for cross-device unlock when
        the licensed app build checks entitlements.
      </p>
      <h2>Margin check</h2>
      <PricingTable />
    </article>
  );
}
