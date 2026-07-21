import type { APIEvent } from "@solidjs/start/server";
import { createLicenseCheckoutSession } from "../../lib/license";
import type { PlanId } from "../../lib/pricing";

/**
 * Creates a Stripe Checkout Session for yearly ($30) or lifetime ($100).
 * Requires a server-capable SolidStart preset (not GitHub Pages static).
 * On static hosting, use VITE_STRIPE_PAYMENT_LINK_YEARLY / _LIFETIME instead.
 */
export async function POST(event: APIEvent) {
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    return new Response(
      JSON.stringify({
        error: "STRIPE_SECRET_KEY not configured",
        hint: "Use VITE_STRIPE_PAYMENT_LINK_YEARLY / VITE_STRIPE_PAYMENT_LINK_LIFETIME on static GitHub Pages, or deploy with a server preset.",
      }),
      { status: 503, headers: { "content-type": "application/json" } },
    );
  }

  const origin = new URL(event.request.url).origin;
  let email: string | undefined;
  let plan: PlanId = "lifetime";
  try {
    const body = (await event.request.json()) as {
      email?: string;
      plan?: string;
    };
    email = body.email;
    if (body.plan === "yearly" || body.plan === "lifetime") {
      plan = body.plan;
    }
  } catch {
    // optional body
  }

  const session = await createLicenseCheckoutSession(secret, {
    successUrl: `${origin}/buy/success?session_id={CHECKOUT_SESSION_ID}`,
    cancelUrl: `${origin}/buy`,
    customerEmail: email,
    plan,
  });

  return new Response(JSON.stringify(session), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}
