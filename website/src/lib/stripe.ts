/**
 * Stripe integration for InstaLay licenses (yearly subscription + lifetime).
 *
 * GitHub Pages is static — checkout uses Payment Links via public env.
 * When you move off static hosting, enable the API route in
 * `src/routes/api/checkout.ts` to create Checkout Sessions and fulfill
 * licenses via webhook (`src/routes/api/stripe-webhook.ts`).
 */
import type { PlanId } from "./pricing";

export function stripePaymentLink(plan?: PlanId): string | undefined {
  if (plan === "yearly") {
    return import.meta.env.VITE_STRIPE_PAYMENT_LINK_YEARLY || undefined;
  }
  if (plan === "lifetime") {
    return (
      import.meta.env.VITE_STRIPE_PAYMENT_LINK_LIFETIME ||
      import.meta.env.VITE_STRIPE_PAYMENT_LINK ||
      import.meta.env.VITE_STRIPE_BUY_BUTTON_URL ||
      undefined
    );
  }
  // No plan: any configured link counts as “checkout ready”
  return (
    import.meta.env.VITE_STRIPE_PAYMENT_LINK_LIFETIME ||
    import.meta.env.VITE_STRIPE_PAYMENT_LINK_YEARLY ||
    import.meta.env.VITE_STRIPE_PAYMENT_LINK ||
    import.meta.env.VITE_STRIPE_BUY_BUTTON_URL ||
    undefined
  );
}

export function stripePublishableKey(): string | undefined {
  return import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || undefined;
}

export function hasCheckoutConfigured(plan?: PlanId): boolean {
  if (plan) {
    return Boolean(stripePaymentLink(plan) || stripePublishableKey());
  }
  return Boolean(stripePaymentLink() || stripePublishableKey());
}
