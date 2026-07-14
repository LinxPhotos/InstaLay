/**
 * Server-side Stripe helpers (used when SolidStart runs with a server preset).
 * Safe to import only from server routes / workers.
 */
import {
  LICENSE_PRODUCT,
  LIST_PRICE_USD,
  assertPricingFloor,
} from "./pricing";

assertPricingFloor(LIST_PRICE_USD);

export interface CheckoutSessionInput {
  successUrl: string;
  cancelUrl: string;
  customerEmail?: string;
}

export async function createLifetimeCheckoutSession(
  stripeSecretKey: string,
  input: CheckoutSessionInput,
): Promise<{ id: string; url: string | null }> {
  const Stripe = (await import("stripe")).default;
  const stripe = new Stripe(stripeSecretKey);

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    success_url: input.successUrl,
    cancel_url: input.cancelUrl,
    customer_email: input.customerEmail,
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "usd",
          unit_amount: Math.round(LICENSE_PRODUCT.priceUsd * 100),
          product_data: {
            name: LICENSE_PRODUCT.name,
            description: LICENSE_PRODUCT.summary,
            metadata: { sku: LICENSE_PRODUCT.sku },
          },
        },
      },
    ],
    metadata: {
      sku: LICENSE_PRODUCT.sku,
      license_type: "universal_lifetime",
      platforms: "windows,macos,linux,android,ios,web",
    },
    payment_intent_data: {
      metadata: {
        sku: LICENSE_PRODUCT.sku,
        license_type: "universal_lifetime",
      },
    },
    allow_promotion_codes: true,
  });

  return { id: session.id, url: session.url };
}

/**
 * Fulfill a paid Checkout Session: mint a license entitlement record.
 * Replace the in-memory stub with KV/D1/Postgres when hosting for real.
 */
export type LicenseRecord = {
  licenseKey: string;
  email: string;
  sku: string;
  platforms: string[];
  createdAt: string;
  stripeSessionId: string;
};

export function mintLicenseKey(seed: string): string {
  // Deterministic-looking but opaque key shape: IL-XXXX-XXXX-XXXX-XXXX
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  const hex = Math.abs(h).toString(16).padStart(8, "0").toUpperCase();
  const a = hex.slice(0, 4);
  const b = hex.slice(4, 8);
  const c = (h >>> 0).toString(16).slice(0, 4).toUpperCase().padStart(4, "0");
  const d = seed
    .replace(/[^a-zA-Z0-9]/g, "")
    .slice(-4)
    .toUpperCase()
    .padEnd(4, "X");
  return `IL-${a}-${b}-${c}-${d}`;
}

export function fulfillCheckoutSession(params: {
  sessionId: string;
  email: string;
}): LicenseRecord {
  const licenseKey = mintLicenseKey(`${params.sessionId}:${params.email}`);
  return {
    licenseKey,
    email: params.email,
    sku: LICENSE_PRODUCT.sku,
    platforms: ["windows", "macos", "linux", "android", "ios", "web"],
    createdAt: new Date().toISOString(),
    stripeSessionId: params.sessionId,
  };
}
