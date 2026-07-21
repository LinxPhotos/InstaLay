import { For } from "solid-js";
import {
  LIFETIME_PRICE_USD,
  UNIT_COGS_USD,
  WORST_TAKE_RATE,
  marketplaceRows,
} from "../lib/pricing";

export function PricingTable(props: { listPrice?: number }) {
  const price = () => props.listPrice ?? LIFETIME_PRICE_USD;
  const rows = () => marketplaceRows(price());
  return (
    <div>
      <p class="muted">
        Unit cost allocation ${UNIT_COGS_USD.toFixed(2)} · worst take rate{" "}
        {(WORST_TAKE_RATE * 100).toFixed(0)}% (Apple) · list $
        {price().toFixed(2)} (lifetime)
      </p>
      <table class="pricing">
        <thead>
          <tr>
            <th>Marketplace</th>
            <th>Take</th>
            <th>Your net</th>
            <th>Margin</th>
            <th>≥100%?</th>
          </tr>
        </thead>
        <tbody>
          <For each={rows()}>
            {(r) => (
              <tr>
                <td>
                  <strong>{r.name}</strong>
                  <div class="muted">{r.notes}</div>
                </td>
                <td>{(r.takeRate * 100).toFixed(1)}%</td>
                <td>${r.net.toFixed(2)}</td>
                <td>{r.marginPct.toFixed(1)}%</td>
                <td class={r.meetsTarget ? "ok" : "bad"}>
                  {r.meetsTarget ? "Yes" : "No"}
                </td>
              </tr>
            )}
          </For>
        </tbody>
      </table>
    </div>
  );
}
