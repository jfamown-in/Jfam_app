
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

async function createRazorpayQr(attempt: any) {
  const keyId = env("RAZORPAY_KEY_ID");
  const keySecret = env("RAZORPAY_KEY_SECRET");
  const auth = btoa(`${keyId}:${keySecret}`);
  const closeBy = Math.floor(Date.now() / 1000) + 15 * 60;

  const response = await fetch("https://api.razorpay.com/v1/payments/qr_codes", {
    method: "POST",
    headers: {
      authorization: `Basic ${auth}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      type: "upi_qr",
      name: "JFAM Fresh Dairy",
      usage: "single_use",
      fixed_amount: true,
      payment_amount: attempt.amount_paise,
      description: `JFAM order ${attempt.order_id}`,
      close_by: closeBy,
      notes: {
        payment_attempt_id: attempt.id,
        order_id: attempt.order_id,
      },
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data?.error?.description || `Razorpay QR create failed: ${response.status}`);

  return {
    raw: data,
    qrId: data.id,
    imageUrl: data.image_url,
    shortUrl: data.short_url || data.image_url,
    expiresAt: data.close_by ? new Date(Number(data.close_by) * 1000).toISOString() : null,
  };
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method not allowed" }, 405);

  try {
    const projectUrl = env("SUPABASE_URL").replace(/\/$/, "");
    const anonKey = env("SUPABASE_ANON_KEY");
    const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
    const token = bearer(req);
    const user = await getUser(projectUrl, anonKey, token);
    const body = await req.json().catch(() => ({}));
    const attemptId = String(body.paymentAttemptId || body.attemptId || "").trim();
    if (!attemptId) return jsonResponse({ error: "paymentAttemptId required" }, 422);

    const rows = await restJson(
      projectUrl,
      serviceKey,
      `payment_attempts?id=eq.${encodeURIComponent(attemptId)}&user_id=eq.${encodeURIComponent(user.id)}&select=*`
    );
    const attempt = rows?.[0];
    if (!attempt) return jsonResponse({ error: "payment attempt not found" }, 404);
    if (attempt.payment_method !== "upi") return jsonResponse({ error: "payment attempt is not UPI" }, 422);
    if (attempt.amount_paise <= 0) return jsonResponse({ error: "nothing payable" }, 422);
    if (!["requires_action", "pending"].includes(attempt.status)) {
      return jsonResponse({ attemptId: attempt.id, status: attempt.status, amount: attempt.amount });
    }
    if (attempt.provider_qr_id && attempt.qr_image_url) {
      return jsonResponse({
        attemptId: attempt.id,
        qrId: attempt.provider_qr_id,
        imageUrl: attempt.qr_image_url,
        shortUrl: attempt.qr_short_url,
        expiresAt: attempt.expires_at,
        amount: attempt.amount,
        status: attempt.status,
      });
    }

    const qr = await createRazorpayQr(attempt);
    const updated = await restJson(projectUrl, serviceKey, "rpc/mark_razorpay_qr_created", {
      method: "POST",
      body: JSON.stringify({
        p_payment_attempt_id: attempt.id,
        p_provider_qr_id: qr.qrId,
        p_image_url: qr.imageUrl,
        p_short_url: qr.shortUrl,
        p_expires_at: qr.expiresAt,
        p_provider_payload: qr.raw,
      }),
    });

    return jsonResponse({
      attemptId: attempt.id,
      qrId: updated.qrId || qr.qrId,
      imageUrl: updated.imageUrl || qr.imageUrl,
      shortUrl: updated.shortUrl || qr.shortUrl,
      expiresAt: updated.expiresAt || qr.expiresAt,
      amount: attempt.amount,
      status: attempt.status,
    });
  } catch (error) {
    console.error("razorpay-create-qr", error instanceof Error ? error.message : error);
    return jsonResponse({ error: "payment QR could not be created" }, 500);
  }
});
