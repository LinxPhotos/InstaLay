import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { BuyButton } from "../../components/BuyButton";
import { PricingTable } from "../../components/PricingTable";
import {
  EDITIONS,
  LICENSE_PLANS,
  LIFETIME_PRICE_USD,
  MIN_LIST_PRICE,
  UNIT_COGS_USD,
  WORST_TAKE_RATE,
  YEARLY_PRICE_USD,
} from "../../lib/pricing";

export default function PricingDocs() {
  return (
    <article class="prose">
      <Title>Pricing — InstaLay</Title>
      <h1>Pricing</h1>
      <p class="lede">
        Two names, one app. {EDITIONS.paid.summary}
      </p>

      <div class="plan-grid">
        <div class="plan">
          <h2>{EDITIONS.free.name}</h2>
          <p class="price-hero">$0</p>
          <p>{EDITIONS.free.summary}</p>
          <A class="btn btn-ghost" href="/buy">
            Buy InstaLay instead
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
          {LICENSE_PLANS.yearly.intervalLabel}. Subscription via Stripe.
        </li>
        <li>
          <strong>Lifetime</strong> — ${LIFETIME_PRICE_USD.toFixed(0)} one-time.
          Permanent license.
        </li>
      </ul>

      <h2>100% margin floor (lifetime, worst marketplace)</h2>
      <p>
        Margin is <code>(net − unit COGS) / unit COGS</code> with unit COGS = $
        {UNIT_COGS_USD.toFixed(2)} (support, signing seats, CDN, payment ops per
        seat). The least profitable marketplace is Apple at{" "}
        {(WORST_TAKE_RATE * 100).toFixed(0)}% take → you keep{" "}
        {((1 - WORST_TAKE_RATE) * 100).toFixed(0)}%.
      </p>
      <p>
        For margin ≥ 100%: net ≥ ${UNIT_COGS_USD * 2}, so list price ≥ $
        {MIN_LIST_PRICE.toFixed(2)}. Lifetime lists at $
        {LIFETIME_PRICE_USD.toFixed(2)}. Yearly is a support subscription, not
        sized to that floor.
      </p>
      <PricingTable />
    </article>
  );
}
