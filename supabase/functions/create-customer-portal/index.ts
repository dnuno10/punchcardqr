import { HttpError, requireOwner, serve } from "../_shared/lib.ts";
import { ownerBusiness, returnUrl, stripe } from "../_shared/stripe.ts";

serve(async (_body, req) => {
  const { sub } = await ownerBusiness(await requireOwner(req));
  if (!sub.stripe_customer_id) throw new HttpError(409, "no_billing_account");
  const session = await stripe.billingPortal.sessions.create({
    customer: sub.stripe_customer_id, return_url: returnUrl(),
  });
  return { url: session.url };
});
