import type { APIEvent } from "@solidjs/start/server";
import { fulfillCheckoutSession } from "../../lib/license";

/**
 * Stripe webhook for checkout.session.completed → mint IL- license keys.
 * Deploy with a server (or Cloudflare Worker) — not available on pure GH Pages.
 */
export async function POST(event: APIEvent) {
  const secret = process.env.STRIPE_SECRET_KEY;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret || !webhookSecret) {
    return new Response("Stripe webhook not configured", { status: 503 });
  }

  const Stripe = (await import("stripe")).default;
  const stripe = new Stripe(secret);
  const sig = event.request.headers.get("stripe-signature");
  if (!sig) return new Response("Missing signature", { status: 400 });

  const raw = await event.request.text();
  let stripeEvent;
  try {
    stripeEvent = stripe.webhooks.constructEvent(raw, sig, webhookSecret);
  } catch (err) {
    return new Response(`Webhook Error: ${(err as Error).message}`, {
      status: 400,
    });
  }

  if (stripeEvent.type === "checkout.session.completed") {
    const session = stripeEvent.data.object as {
      id: string;
      customer_details?: { email?: string | null };
      customer_email?: string | null;
      metadata?: { license_type?: string };
    };
    const email =
      session.customer_details?.email ||
      session.customer_email ||
      "unknown@buyer.local";
    const planMeta = session.metadata?.license_type;
    const plan =
      planMeta === "yearly" || planMeta === "lifetime" ? planMeta : "lifetime";
    const license = fulfillCheckoutSession({
      sessionId: session.id,
      email,
      plan,
    });
    // Persist `license` to your DB / email provider here.
    console.log("LICENSE_ISSUED", JSON.stringify(license));
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "content-type": "application/json" },
  });
}
