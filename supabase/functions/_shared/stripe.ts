import Stripe from "npm:stripe@17";
import { admin, appUrl, HttpError } from "./lib.ts";

export const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  httpClient: Stripe.createFetchHttpClient(),
});

// Stripe product/price IDs are stable per-environment identifiers, not secrets — hardcoded here
// so only STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET need to be set as Supabase secrets.
export const PRODUCT_BY_PLAN: Record<string, string> = {
  starter: "prod_VIuLTEt15EL5UI",
  pro: "prod_VIuLlcdyTLvBZP",
};

export const PRICE_BY_PLAN: Record<string, string> = {
  starter: "price_1UIIWM3kPVs6fjFLwqWmJRPS",
  pro: "price_1UIIXC3kPVs6fjFLY1w61h6P",
};

export function planForPrice(priceId?: string): "starter" | "pro" | null {
  if (priceId && priceId === PRICE_BY_PLAN.starter) return "starter";
  if (priceId && priceId === PRICE_BY_PLAN.pro) return "pro";
  return null;
}

/** The owner's business + subscription row. Owners only ever act on their own business. */
export async function ownerBusiness(ownerId: string) {
  const { data: business } = await admin().from("businesses").select("id, name").eq("owner_id", ownerId)
    .order("created_at").limit(1).maybeSingle();
  if (!business) throw new HttpError(404, "business_not_found");
  const { data: sub } = await admin().from("subscriptions").select("*").eq("business_id", business.id).single();
  return { business, sub };
}

export const returnUrl = () => `${appUrl()}/billing`;
