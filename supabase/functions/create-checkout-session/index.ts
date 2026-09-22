import Stripe from "npm:stripe@17";
import { admin, HttpError, requireOwner, serve } from "../_shared/lib.ts";
import { ownerBusiness, PRICE_BY_PLAN, returnUrl, stripe } from "../_shared/stripe.ts";

serve(async (body, req) => {
  const owner = await requireOwner(req);
  const plan = String(body.plan);
  const price = PRICE_BY_PLAN[plan];
  if (!price) throw new HttpError(400, "invalid_plan");

  const { business, sub } = await ownerBusiness(owner);
  if (sub.stripe_subscription_id && sub.status !== "canceled") throw new HttpError(409, "already_subscribed");

  try {
    let customerId = sub.stripe_customer_id as string | null;
    if (!customerId) {
      const c = await stripe.customers.create({ name: business.name, metadata: { business_id: business.id } });
      customerId = c.id;
      await admin().from("subscriptions").update({ stripe_customer_id: customerId }).eq("business_id", business.id);
    }

    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer: customerId,
      client_reference_id: business.id,
      line_items: [{ price, quantity: 1 }],
      subscription_data: { metadata: { business_id: business.id } },
      success_url: `${returnUrl()}?checkout=success`,
      cancel_url: `${returnUrl()}?checkout=cancelled`,
    });
    return { url: session.url };
  } catch (e) {
    // Surface Stripe's real reason (e.g. "No such price") instead of a generic 500 —
    // this class of error is config, not a bug, and needs to be actionable.
    if (e instanceof Stripe.errors.StripeError) {
      throw new HttpError(502, "stripe_error", { message: e.message, plan });
    }
    throw e;
  }
});
