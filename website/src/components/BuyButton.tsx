import {
  LICENSE_PLANS,
  type PlanId,
} from "../lib/pricing";
import { linxInstalayBuyUrl } from "../lib/linx";

/** CTA that sends buyers to linx.photos InstaLay checkout. */
export function BuyButton(props: {
  plan?: PlanId;
  label?: string;
  class?: string;
}) {
  const planId = () => props.plan ?? "lifetime";
  const plan = () => LICENSE_PLANS[planId()];
  const href = () => linxInstalayBuyUrl(planId());

  const defaultLabel = () => {
    const p = plan();
    if (p.intervalLabel) {
      return `Buy InstaLay — $${p.priceUsd.toFixed(0)}/${p.intervalLabel}`;
    }
    return `Buy InstaLay — $${p.priceUsd.toFixed(0)} lifetime`;
  };

  return (
    <a
      class={`btn btn-primary ${props.class ?? ""}`}
      href={href()}
      rel="noopener noreferrer"
    >
      {props.label ?? defaultLabel()}
    </a>
  );
}
