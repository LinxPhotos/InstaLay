import { Title } from "@solidjs/meta";
import { PricingTable } from "../../components/PricingTable";
import { BuyButton } from "../../components/BuyButton";
import {
  LICENSE_PRODUCT,
  LIST_PRICE_USD,
  MIN_LIST_PRICE,
  UNIT_COGS_USD,
  WORST_TAKE_RATE,
} from "../../lib/pricing";

export default function PricingDocs() {
  return (
    <article class="prose">
      <Title>Pricing — InstaLay</Title>
      <h1>Universal lifetime license</h1>
      <p class="price-hero">${LIST_PRICE_USD.toFixed(2)}</p>
      <p>
        {LICENSE_PRODUCT.summary} Same list price is used on Apple, Google Play,
        Microsoft Store, and direct checkout so storefronts stay aligned.
      </p>
      <BuyButton />

      <h2>100% margin floor (worst marketplace)</h2>
      <p>
        Margin is <code>(net − unit COGS) / unit COGS</code> with unit COGS = $
        {UNIT_COGS_USD.toFixed(2)} (support, signing seats, CDN, payment ops per
        seat). The least profitable marketplace is Apple at{" "}
        {(WORST_TAKE_RATE * 100).toFixed(0)}% take → you keep{" "}
        {((1 - WORST_TAKE_RATE) * 100).toFixed(0)}%.
      </p>
      <p>
        For margin ≥ 100%: net ≥ ${UNIT_COGS_USD * 2}, so list price ≥ $
        {MIN_LIST_PRICE.toFixed(2)}. We list at ${LIST_PRICE_USD.toFixed(2)}.
      </p>
      <PricingTable />
      <p class="muted">
        When you later add subscriptions, keep one-time lifetime as a parallel
        SKU or grandfather path; this site already isolates payment code under
        <code> src/lib/</code> and <code>src/routes/api/</code>.
      </p>
    </article>
  );
}
