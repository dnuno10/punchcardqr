import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": Deno.env.get("ALLOWED_ORIGIN") ?? "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(public status: number, public code: string, public extra: Record<string, unknown> = {}) {
    super(code);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Wraps a handler: CORS preflight, POST-only, JSON body parsing and uniform error responses. */
export function serve(fn: (body: Record<string, unknown>, req: Request) => Promise<unknown>) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      if (req.method !== "POST") throw new HttpError(405, "method_not_allowed");
      const body = await req.json().catch(() => ({}));
      return json(await fn(body ?? {}, req));
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.code, ...e.extra }, e.status);
      console.error(e);
      return json({ error: "internal" }, 500);
    }
  });
}

let _admin: SupabaseClient | null = null;
/** Service-role client. Only ever used server-side; RLS is bypassed, so callers must authorize first. */
export function admin(): SupabaseClient {
  return _admin ??= createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/** Verifies the owner's JWT and returns their user id. */
export async function requireOwner(req: Request): Promise<string> {
  const auth = req.headers.get("Authorization");
  if (!auth) throw new HttpError(401, "unauthorized");
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } }, auth: { persistSession: false } },
  );
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new HttpError(401, "unauthorized");
  return data.user.id;
}

// Postgres exceptions raised in 0003/0004 → HTTP.
const PG_ERRORS: Record<string, number> = {
  forbidden: 403,
  card_not_found: 404,
  program_not_available: 404,
  reward_not_found: 404,
  nothing_to_reverse: 404,
  customer_limit_reached: 402,
  punch_limit_reached: 402,
  cooldown_active: 429,
  membership_not_active: 409,
  program_not_active: 409,
  reward_already_redeemed: 409,
  reward_not_available: 409,
  reward_expired: 409,
  reward_already_used: 409,
  not_reversible: 409,
  invalid_location: 400,
  recovery_invalid: 410,
};

export async function rpc<T = unknown>(name: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await admin().rpc(name, args);
  if (error) {
    const [code, arg] = error.message.split(":");
    const status = PG_ERRORS[code];
    if (!status) {
      console.error(`rpc ${name} failed`, error);
      throw new HttpError(500, "internal");
    }
    throw new HttpError(status, code, code === "cooldown_active" ? { seconds_since_last: Number(arg) } : {});
  }
  return data as T;
}

// ───────── crypto ─────────
const enc = new TextEncoder();

export function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

export function hex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function fromHex(h: string): Uint8Array {
  return Uint8Array.from(h.match(/.{2}/g)!.map((x) => parseInt(x, 16)));
}

export function randomBytes(n: number): Uint8Array {
  return crypto.getRandomValues(new Uint8Array(n));
}

export async function sha256Hex(s: string): Promise<string> {
  return hex(new Uint8Array(await crypto.subtle.digest("SHA-256", enc.encode(s))));
}

export async function hmac(secret: Uint8Array, msg: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", secret, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64url(new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(msg))));
}

export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Fresh secrets for a card. Only hashes / the HMAC key ever reach the database. */
export async function newCardSecrets() {
  const token = b64url(randomBytes(32)); // 256 bits, goes in the /c/{token} URL
  return {
    token,
    tokenHash: await sha256Hex(token),
    scanId: b64url(randomBytes(9)),
    scanSecretPg: `\\x${hex(randomBytes(32))}`, // bytea literal for PostgREST
  };
}

export function requireToken(v: unknown): string {
  if (typeof v !== "string" || !/^[A-Za-z0-9_-]{43}$/.test(v)) throw new HttpError(404, "card_not_found");
  return v;
}

export function requireString(v: unknown, name: string, max = 200): string {
  if (typeof v !== "string" || v.length === 0 || v.length > max) throw new HttpError(400, `invalid_${name}`);
  return v;
}

// ───────── abuse protection ─────────
export function clientIp(req: Request): string {
  return req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0].trim() ?? "unknown";
}

export async function rateLimit(key: string, max: number, windowSecs: number) {
  const ok = await rpc<boolean>("check_rate_limit", { p_key: key, p_max: max, p_window_secs: windowSecs });
  if (!ok) throw new HttpError(429, "rate_limited");
}

/** Cloudflare Turnstile. Enforced only when TURNSTILE_SECRET_KEY is configured. */
export async function verifyCaptcha(token: unknown, ip: string) {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret) return;
  if (typeof token !== "string") throw new HttpError(400, "captcha_required");
  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    body: new URLSearchParams({ secret, response: token, remoteip: ip }),
  });
  if (!(await res.json()).success) throw new HttpError(400, "captcha_failed");
}

// ───────── scan QR ─────────
export const SCAN_TTL_SECS = 60;

export async function mintScanCode(scanId: string, secretHex: string) {
  const exp = Math.floor(Date.now() / 1000) + SCAN_TTL_SECS;
  const sig = await hmac(fromHex(secretHex), `${scanId}.${exp}`);
  return { code: `pcq1.${scanId}.${exp}.${sig}`, expires_at: exp };
}

export function parseScanCode(code: unknown): { scanId: string; exp: number; sig: string } {
  const parts = typeof code === "string" ? code.split(".") : [];
  if (parts.length !== 4 || parts[0] !== "pcq1") throw new HttpError(400, "invalid_scan_code");
  return { scanId: parts[1], exp: Number(parts[2]), sig: parts[3] };
}

// ───────── realtime ─────────
/** Tells the open customer card to refetch. Payload is empty on purpose: no data leaks via the channel. */
export async function notifyCard(membershipId: string) {
  try {
    const channel = await rpc<string>("membership_channel", { p_membership: membershipId });
    await fetch(`${Deno.env.get("SUPABASE_URL")}/realtime/v1/api/broadcast`, {
      method: "POST",
      headers: {
        apikey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ messages: [{ topic: `card:${channel}`, event: "changed", payload: {}, private: false }] }),
    });
  } catch (e) {
    console.error("broadcast failed", e); // never fail the punch because realtime hiccuped
  }
}

export function appUrl(): string {
  return Deno.env.get("APP_URL") ?? "https://app.punchcardqr.com";
}
