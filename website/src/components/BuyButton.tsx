import { Show } from "solid-js";
import { LICENSE_PRODUCT } from "../lib/pricing";
import { hasCheckoutConfigured, stripePaymentLink } from "../lib/stripe";

export function BuyButton(props: { label?: string; class?: string }) {
  const link = () => stripePaymentLink();
  const ready = () => hasCheckoutConfigured() && Boolean(link());

  return (
    <Show
      when={ready()}
      fallback={
        <a class={`btn btn-primary ${props.class ?? ""}`} href="/buy">
          {props.label ?? `Buy license — $${LICENSE_PRODUCT.priceUsd.toFixed(2)}`}
        </a>
      }
    >
      <a
        class={`btn btn-primary ${props.class ?? ""}`}
        href={link()}
        rel="noopener noreferrer"
      >
        {props.label ?? `Buy license — $${LICENSE_PRODUCT.priceUsd.toFixed(2)}`}
      </a>
    </Show>
  );
}
