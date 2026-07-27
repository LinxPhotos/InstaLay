import { Title } from "@solidjs/meta";
import { onMount } from "solid-js";
import { LINX } from "../../lib/linx";

/** Legacy success page — ownership now lives on Linx account. */
export default function BuySuccessRedirect() {
  onMount(() => {
    window.location.replace(LINX.instalayAccount);
  });

  return (
    <article class="prose">
      <Title>Thank you — InstaLay</Title>
      <h1>Redirecting…</h1>
      <p>
        View your license on{" "}
        <a href={LINX.instalayAccount} rel="noopener noreferrer">
          Linx Photos → Account → InstaLay
        </a>
        .
      </p>
    </article>
  );
}
