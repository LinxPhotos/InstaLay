import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { PricingTable } from "../../components/PricingTable";
import {
  LIFETIME_PRICE_USD,
  MIN_LIST_PRICE,
  UNIT_COGS_USD,
  WORST_TAKE_RATE,
} from "../../lib/pricing";

export default function MarketplaceMargin() {
  return (
    <article class="prose">
      <Title>Marketplace margin - InstaLay</Title>
      <h1>Marketplace margin</h1>
      <p class="lede">
        This page shows how the lifetime price was checked against app-store fees.
        It is not part of buying a license.{" "}
        <A href="/docs/pricing">Back to pricing</A>.
      </p>
      <h2>Lifetime price after store fees</h2>
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