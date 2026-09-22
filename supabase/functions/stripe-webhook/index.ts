import Stripe from "npm:stripe@17";
import { admin } from "../_shared/lib.ts";
import { planForPrice, stripe } from "../_shared/stripe.ts";

// Stripe subscription statuses -> our sub_status enum ('active' | 'trialing' | 'past_due' | 'canceled').
function mapStatus(s: Stripe.Subscription.Status): "active" | "trialing" | "past_due" | "canceled" {
  switch (s) {
    case "active": return "active";
    case "trialing": return "trialing";
    case "past_due": case "unpaid": case "incomplete": return "past_due";
    default: return "canceled"; // canceled, incomplete_expired, paused
  }
}

async function syncFromSubscription(sub: Stripe.Subscription) {
  const priceId = sub.items.data[0]?.price?.id;
  const plan = planForPrice(priceId) ?? "free";
  const status = mapStatus(sub.status);

  // stripe@17 pins an API version where current_period_start/end still live on the
  // subscription itself (they only moved to the subscription item in later API versions).
  const { error } = await admin().from("subscriptions").update({
    plan,
    status,
    stripe_subscription_id: sub.id,
    stripe_price_id: priceId ?? null,
    current_period_start: sub.current_period_start
      ? new Date(sub.current_period_start * 1000).toISOString()
      : null,
    current_period_end: sub.current_period_end
      ? new Date(sub.current_period_end * 1000).toISOString()
      : null,
    cancel_at_period_end: sub.cancel_at_period_end,
  }).eq("stripe_customer_id", sub.customer as string);

  if (error) console.error("subscriptions update failed", error);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method_not_allowed", { status: 405 });

  const signature = req.headers.get("Stripe-Signature");
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  if (!signature || !secret) return new Response("missing_signature", { status: 400 });

  const payload = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(payload, signature, secret);
  } catch (err) {
    console.error("signature verification failed", err);
    return new Response("invalid_signature", { status: 400 });
  }

  try {
    switch (event.type) {
      // Checkout finished — the subscription may not be fully synced onto the customer
      // yet in every case, so pull it fresh from Stripe and write it down ourselves
      // rather than trusting session fields alone.
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        if (session.mode === "subscription" && session.subscription) {
          const sub = await stripe.subscriptions.retrieve(session.subscription as string);
          await syncFromSubscription(sub);
        }
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        await syncFromSubscription(event.data.object as Stripe.Subscription);
        break;
      }

      case "customer.subscription.deleted": {
        const sub = event.data.object as Stripe.Subscription;
        const { error } = await admin().from("subscriptions").update({
          plan: "free",
          status: "canceled",
          stripe_subscription_id: null,
          stripe_price_id: null,
          cancel_at_period_end: false,
        }).eq("stripe_customer_id", sub.customer as string);
        if (error) console.error("subscriptions cancel failed", error);
        break;
      }

      default:
        // Ignore anything we don't act on.
        break;
    }
  } catch (e) {
    console.error(`webhook handling failed for ${event.type}`, e);
    // Still 200 — Stripe retries on non-2xx, and a handler bug shouldn't cause a retry storm.
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
