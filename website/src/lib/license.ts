/**
 * Server-side Stripe helpers (used when SolidStart runs with a server preset).
 * Safe to import only from server routes / workers.
 */
import {
  LICENSE_PLANS,
  LIFETIME_PRICE_USD,
  assertPricingFloor,
  type PlanId,
  type LicensePlan,
} from "./pricing";

assertPricingFloor(LIFETIME_PRICE_USD);

export interface CheckoutSessionInput {
  successUrl: string;
  cancelUrl: string;
  customerEmail?: string;
  /**
   * Stable id for Adapty (and other subscription platforms).
   * Prefer the authenticated user id; fall back to lowercased checkout email.
   * Must match what the mobile app passes to `Adapty().identify(...)`.
   */
  customerUserId?: string;
  plan?: PlanId;
}

/** Normalize buyer identity for Stripe metadata → Adapty web sync. */
export function resolveCustomerUserId(input: {
  customerUserId?: string;
  customerEmail?: string;
}): string | undefined {
  const explicit = input.customerUserId?.trim();
  if (explicit) return explicit;
  const email = input.customerEmail?.trim().toLowerCase();
  return email || undefined;
}

export async function createLicenseCheckoutSession(
  stripeSecretKey: string,
  input: CheckoutSessionInput,
): Promise<{ id: string; url: string | null }> {
  const plan = LICENSE_PLANS[input.plan ?? "lifetime"];
  const Stripe = (await import("stripe")).default;
  const stripe = new Stripe(stripeSecretKey);
  const customerUserId = resolveCustomerUserId(input);

  const priceData =
    plan.mode === "subscription"
      ? {
          currency: "usd" as const,
          unit_amount: Math.round(plan.priceUsd * 100),
          recurring: { interval: "year" as const },
          product_data: {
            name: plan.name,
            description: plan.summary,
            metadata: { sku: plan.sku },
          },
        }
      : {
          currency: "usd" as const,
          unit_amount: Math.round(plan.priceUsd * 100),
          product_data: {
            name: plan.name,
            description: plan.summary,
            metadata: { sku: plan.sku },
          },
        };

  const sharedMeta: Record<string, string> = {
    sku: plan.sku,
    license_type: plan.id,
    platforms: "windows,macos,linux,android,ios,web",
  };
  if (customerUserId) {
    sharedMeta.customer_user_id = customerUserId;
  }

  const session = await stripe.checkout.sessions.create({
    mode: plan.mode,
    success_url: input.successUrl,
    cancel_url: input.cancelUrl,
    customer_email: input.customerEmail,
    client_reference_id: customerUserId,
    line_items: [{ quantity: 1, price_data: priceData }],
    metadata: sharedMeta,
    ...(plan.mode === "payment"
      ? {
          // Adapty Stripe sync needs invoice events for one-time Checkout.
          invoice_creation: { enabled: true },
          payment_intent_data: {
            metadata: {
              sku: plan.sku,
              license_type: plan.id,
              ...(customerUserId
                ? { customer_user_id: customerUserId }
                : {}),
            },
          },
        }
      : {
          subscription_data: customerUserId
            ? { metadata: { customer_user_id: customerUserId } }
            : undefined,
        }),
    allow_promotion_codes: true,
  });

  return { id: session.id, url: session.url };
}

/** @deprecated Use createLicenseCheckoutSession */
export async function createLifetimeCheckoutSession(
  stripeSecretKey: string,
  input: CheckoutSessionInput,
): Promise<{ id: string; url: string | null }> {
  return createLicenseCheckoutSession(stripeSecretKey, {
    ...input,
    plan: "lifetime",
  });
}

/**
 * Fulfill a paid Checkout Session: mint a license entitlement record.
 * Replace the in-memory stub with KV/D1/Postgres when hosting for real.
 */
export type LicenseRecord = {
  licenseKey: string;
  email: string;
  sku: string;
  plan: PlanId;
  platforms: string[];
  createdAt: string;
  stripeSessionId: string;
  /** Same id sent to Adapty / Stripe metadata when known. */
  customerUserId?: string;
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
  plan?: PlanId;
  customerUserId?: string;
}): LicenseRecord {
  const plan: LicensePlan = LICENSE_PLANS[params.plan ?? "lifetime"];
  const licenseKey = mintLicenseKey(`${params.sessionId}:${params.email}`);
  return {
    licenseKey,
    email: params.email,
    sku: plan.sku,
    plan: plan.id,
    platforms: ["windows", "macos", "linux", "android", "ios", "web"],
    createdAt: new Date().toISOString(),
    stripeSessionId: params.sessionId,
    customerUserId: params.customerUserId,
  };
}
