import { Title } from "@solidjs/meta";
import { A } from "@solidjs/router";

export default function LicensingDocs() {
  return (
    <article class="prose">
      <Title>Licensing & subscriptions — InstaLay</Title>
      <h1>Licensing and subscriptions</h1>
      <p class="lede">
        InstaLay Free is the full app. Paid plans support the developer. Access
        is granted by an <code>IL-</code> license key and/or Adapty access
        levels on mobile.
      </p>

      <h2>Plans</h2>
      <ul>
        <li>
          <strong>Yearly</strong> — $30 / year (Stripe subscription)
        </li>
        <li>
          <strong>Lifetime</strong> — $100 once (Stripe one-time; invoice
          creation enabled so Adapty can sync)
        </li>
      </ul>
      <p>
        See <A href="/docs/pricing">pricing</A> and <A href="/buy">buy</A>.
      </p>

      <h2>Desktop: IL- keys</h2>
      <p>
        After Stripe Checkout (server webhook), fulfillment mints an{" "}
        <code>IL-XXXX-XXXX-XXXX-XXXX</code> key. Paste it in the app license
        dialog. This path does not require Adapty.
      </p>

      <h2>Mobile: Adapty</h2>
      <p>
        On iOS/Android,{" "}
        <a href="https://adapty.io/">Adapty</a> is the subscription management
        platform (receipt validation, access levels, analytics). Configure
        access level <code>instalay</code> in the Adapty dashboard and map App
        Store / Play / Stripe products to it.
      </p>
      <ul>
        <li>
          Build with{" "}
          <code>--dart-define=ADAPTY_PUBLIC_SDK_KEY=public_…</code>
        </li>
        <li>
          Connect Adapty’s Stripe app so web Checkout grants the same access
          level
        </li>
        <li>
          Checkout Sessions set metadata{" "}
          <code>customer_user_id</code> (usually the buyer email). The app’s
          Restore flow identifies with that same id.
        </li>
      </ul>

      <h2>Why both?</h2>
      <p>
        Stripe Customer Portal only shows Stripe invoices. App Store / Play
        billing stays in those stores. Adapty (or similar) answers one question
        across rails: <em>does this user have access?</em> Desktop keepers of
        offline IL- keys remain valid without a store account.
      </p>
    </article>
  );
}
