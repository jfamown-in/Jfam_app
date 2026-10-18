
const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type, x-razorpay-signature",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function env(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function bearer(req: Request) {
  const header = req.headers.get("authorization") || "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new Error("authentication required");
  return token;
}

async function getUser(projectUrl: string, anonKey: string, token: string) {
  const response = await fetch(`${projectUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization: `Bearer ${token}` },
  });
  if (!response.ok) throw new Error("authentication failed");
  return await response.json();
}

async function restJson(projectUrl: string, serviceKey: string, path: string, init: RequestInit = {}) {
  const response = await fetch(`${projectUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      authorization: `Bearer ${serviceKey}`,
      "content-type": "application/json",
      accept: "application/json",
      ...(init.headers || {}),
    },
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  if (!response.ok) throw new Error(data?.message || data?.error || `Supabase REST ${response.status}`);
  return data;
}

function hex(buffer: ArrayBuffer) {
  return [...new Uint8Array(buffer)].map(byte => byte.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let i = 0; i < a.length; i += 1) mismatch |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return mismatch === 0;
}

async function verifySignature(rawBody: string, signature: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  return timingSafeEqual(hex(digest), signature);
}

function getPaymentEntity(payload: any) {
  return payload?.payload?.payment?.entity || payload?.payload?.qr_code?.entity || {};
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method not allowed" }, 405);

  try {
    const projectUrl = env("SUPABASE_URL").replace(/\/$/, "");
    const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
    const webhookSecret = env("RAZORPAY_WEBHOOK_SECRET");
    const rawBody = await req.text();
    const signature = req.headers.get("x-razorpay-signature") || "";

    if (!signature || !(await verifySignature(rawBody, signature, webhookSecret))) {
      return jsonResponse({ error: "invalid signature" }, 401);
    }

    const payload = JSON.parse(rawBody);
    const entity = getPaymentEntity(payload);
    const notes = entity?.notes || payload?.payload?.payment?.entity?.notes || {};
    const attemptId = notes.payment_attempt_id || notes.attempt_id;
    if (!attemptId) return jsonResponse({ ok: true, ignored: "missing payment_attempt_id" });

    const eventId = payload?.event_id || payload?.id || `${payload?.event || "event"}:${entity?.id || Date.now()}`;
    const result = await restJson(projectUrl, serviceKey, "rpc/record_razorpay_payment_event", {
      method: "POST",
      body: JSON.stringify({
        p_payment_attempt_id: attemptId,
        p_provider_event_id: eventId,
        p_event_type: payload?.event || "razorpay.webhook",
        p_provider_payment_id: entity?.id || payload?.payload?.payment?.entity?.id || null,
        p_provider_qr_id: entity?.qr_code_id || entity?.id || null,
        p_status: entity?.status || payload?.event || null,
        p_amount_paise: entity?.amount || entity?.payment_amount || null,
        p_raw_payload: payload,
      }),
    });

    return jsonResponse({ ok: true, ...result });
  } catch (error) {
    console.error("razorpay-webhook", error instanceof Error ? error.message : error);
    return jsonResponse({ error: "webhook could not be processed" }, 500);
  }
});
