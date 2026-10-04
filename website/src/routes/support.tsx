import { Title } from "@solidjs/meta";
import { createSignal } from "solid-js";

/** Card fee of 2.9% + $0.30 eats a charge under about $0.31. Stay above that. */
const MIN_USD = 1;

const TIERS = [
  { name: "Bronze", min: 10 },
  { name: "Silver", min: 100 },
  { name: "Gold", min: 1_000 },
  { name: "Platinum", min: 10_000 },
  { name: "Diamond", min: 100_000 },
] as const;

function tierFor(amount: number): string | null {
  if (!Number.isFinite(amount) || amount < 10) return null;
  let name: string | null = null;
  for (const tier of TIERS) {
    if (amount >= tier.min) name = tier.name;
  }
  return name;
}

export default function SupportPage() {
  const [raw, setRaw] = createSignal("10");
  const amount = () => {
    const n = Number(raw());
    return Number.isFinite(n) ? n : 0;
  };
  const tier = () => tierFor(amount());
  const tooSmall = () => amount() > 0 && amount() < MIN_USD;

  return (
    <article class="prose">
      <Title>Donate or Support - InstaLay</Title>
      <h1>Donate or Support</h1>
      <p class="lede">
        Support InstaLay with an amount you choose. It is separate from buying a license.
      </p>
      <label>
        Amount (USD)
        <input
          type="number"
          min={MIN_USD}
          step="1"
          inputMode="decimal"
          value={raw()}
          onInput={(e) => setRaw(e.currentTarget.value)}
        />
      </label>
      <p>
        {tooSmall()
          ? `The smallest amount is $${MIN_USD}. Below that, the card fee takes the whole gift.`
          : tier()
            ? `${tier()} supporter.`
            : "This amount is not given a supporter rank."}
      </p>
      <h2>Supporter ranks</h2>
      <ul>
        <li>Under $10 is not ranked.</li>
        <li>Bronze, $10 and up.</li>
        <li>Silver, $100 and up.</li>
        <li>Gold, $1,000 and up.</li>
        <li>Platinum, $10,000 and up. These names are shown.</li>
        <li>Diamond, $100,000 and up. These names are shown.</li>
      </ul>
      <p class="muted">
        Charging a custom amount is not connected on this site yet. Buying a license is still on the pricing page.
      </p>
    </article>
  );
}
