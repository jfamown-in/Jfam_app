
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

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "method not allowed" }, 405);

  try {
    const projectUrl = env("SUPABASE_URL").replace(/\/$/, "");
    const anonKey = env("SUPABASE_ANON_KEY");
    const token = bearer(req);
    await getUser(projectUrl, anonKey, token);
    const body = await req.json().catch(() => ({}));
    const attemptId = String(body.paymentAttemptId || body.attemptId || "").trim();
    if (!attemptId) return jsonResponse({ error: "paymentAttemptId required" }, 422);

    const response = await fetch(`${projectUrl}/rest/v1/rpc/get_payment_attempt_status`, {
      method: "POST",
      headers: {
        apikey: anonKey,
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({ p_payment_attempt_id: attemptId }),
    });
    const text = await response.text();
    const data = text ? JSON.parse(text) : null;
    if (!response.ok) return jsonResponse({ error: "payment status unavailable" }, response.status);
    return jsonResponse(data);
  } catch (error) {
    console.error("razorpay-payment-status", error instanceof Error ? error.message : error);
    return jsonResponse({ error: "payment status unavailable" }, 500);
  }
});
