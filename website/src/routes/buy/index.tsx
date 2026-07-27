import { Title } from "@solidjs/meta";
import { onMount } from "solid-js";
import { LINX, linxInstalayBuyUrl } from "../../lib/linx";

/**
 * Legacy /buy storefront — funnel to pricing docs, then Linx checkout.
 * Honors ?plan=yearly|lifetime by sending buyers straight to linx.photos.
 */
export default function BuyRedirectPage() {
  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const plan = params.get("plan");
    if (plan === "yearly" || plan === "lifetime") {
      window.location.replace(linxInstalayBuyUrl(plan));
      return;
    }
    const base = import.meta.env.BASE_URL || "/";
    const pricing = `${base.replace(/\/?$/, "/")}docs/pricing`.replace(
      /([^:]\/)\/+/g,
      "$1",
    );
    window.location.replace(pricing);
  });

  return (
    <article class="prose">
      <Title>Buy InstaLay</Title>
      <h1>Redirecting…</h1>
      <p>
        Checkout moved to{" "}
        <a href={LINX.instalayBuy} rel="noopener noreferrer">
          Linx Photos
        </a>
        . See{" "}
        <a href="../docs/pricing">pricing</a> for plan details.
      </p>
    </article>
  );
}
