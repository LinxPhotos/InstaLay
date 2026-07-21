import { Show } from "solid-js";
import {
  LICENSE_PLANS,
  type PlanId,
} from "../lib/pricing";
import { hasCheckoutConfigured, stripePaymentLink } from "../lib/stripe";

export function BuyButton(props: {
  plan?: PlanId;
  label?: string;
  class?: string;
}) {
  const planId = () => props.plan ?? "lifetime";
  const plan = () => LICENSE_PLANS[planId()];
  const link = () => stripePaymentLink(planId());
  const ready = () => hasCheckoutConfigured(planId()) && Boolean(link());

  const defaultLabel = () => {
    const p = plan();
    if (p.intervalLabel) {
      return `Buy InstaLay — $${p.priceUsd.toFixed(0)}/${p.intervalLabel}`;
    }
    return `Buy InstaLay — $${p.priceUsd.toFixed(0)} lifetime`;
  };

  return (
    <Show
      when={ready()}
      fallback={
        <a
          class={`btn btn-primary ${props.class ?? ""}`}
          href={`/buy${props.plan ? `?plan=${props.plan}` : ""}`}
        >
          {props.label ?? defaultLabel()}
        </a>
      }
    >
      <a
        class={`btn btn-primary ${props.class ?? ""}`}
        href={link()}
        rel="noopener noreferrer"
      >
        {props.label ?? defaultLabel()}
      </a>
    </Show>
  );
}
