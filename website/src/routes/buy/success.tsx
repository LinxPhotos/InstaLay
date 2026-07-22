import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";
import { LINX } from "../../lib/linx";

export default function BuySuccess() {
  return (
    <article class="prose">
      <Title>Thank you — InstaLay</Title>
      <h1>You’re licensed</h1>
      <p>
        Thanks for buying InstaLay and supporting the developer. Check your
        email for the Stripe receipt. If automatic license mail is enabled, your{" "}
        <code>IL-····</code> key arrives shortly.
      </p>
      <div class="cta-row">
        <A class="btn btn-primary" href="/download">
          Download builds
        </A>
        <A class="btn btn-ghost" href="/docs/install">
          Install guide
        </A>
        <a class="btn btn-ghost" href={LINX.home} rel="noopener noreferrer">
          Linx Photos
        </a>
      </div>
    </article>
  );
}
