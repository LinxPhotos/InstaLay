import type { APIEvent } from "@solidjs/start/server";
import { createLifetimeCheckoutSession } from "../../lib/license";

/**
 * Creates a Stripe Checkout Session for the universal lifetime license.
 * Requires a server-capable SolidStart preset (not GitHub Pages static).
 * On static hosting, use VITE_STRIPE_PAYMENT_LINK instead.
 */
export async function POST(event: APIEvent) {
  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    return new Response(
      JSON.stringify({
        error: "STRIPE_SECRET_KEY not configured",
        hint: "Use VITE_STRIPE_PAYMENT_LINK on static GitHub Pages, or deploy with a server preset.",
      }),
      { status: 503, headers: { "content-type": "application/json" } },
    );
  }

  const origin = new URL(event.request.url).origin;
  let email: string | undefined;
  try {
    const body = (await event.request.json()) as { email?: string };
    email = body.email;
  } catch {
    // optional body
  }

  const session = await createLifetimeCheckoutSession(secret, {
    successUrl: `${origin}/buy/success?session_id={CHECKOUT_SESSION_ID}`,
    cancelUrl: `${origin}/buy`,
    customerEmail: email,
  });

  return new Response(JSON.stringify(session), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}
