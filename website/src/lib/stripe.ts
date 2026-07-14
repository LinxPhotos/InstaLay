/**
 * Stripe integration for the universal lifetime license.
 *
 * GitHub Pages is static — checkout uses a Payment Link (or Buy Button) at
 * build/runtime via public env. When you move off static hosting, enable the
 * API route in `src/routes/api/checkout.ts` to create Checkout Sessions and
 * fulfill licenses via webhook (`src/server/stripe-webhook.ts`).
 */

export function stripePaymentLink(): string | undefined {
  return (
    import.meta.env.VITE_STRIPE_PAYMENT_LINK ||
    import.meta.env.VITE_STRIPE_BUY_BUTTON_URL ||
    undefined
  );
}

export function stripePublishableKey(): string | undefined {
  return import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || undefined;
}

export function hasCheckoutConfigured(): boolean {
  return Boolean(stripePaymentLink() || stripePublishableKey());
}
