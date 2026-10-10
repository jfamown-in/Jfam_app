import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};

type OrderItem = {
  name?: string;
  product_name?: string;
  quantity?: string;
  packets?: number;
  price?: number;
  plan?: string;
  slot?: string;
};

type OrderPayload = { orderId?: string };

type StoredOrder = {
  id: string;
  payment_mode?: string;
  total_amount?: number;
  customer_name?: string;
  customer_phone?: string;
  order_items?: OrderItem[];
};

function clean(value: unknown) {
  return String(value ?? "").trim();
}

function buildMessage(order: StoredOrder) {
  const items = Array.isArray(order.order_items) ? order.order_items : [];
  const itemLines = items
    .slice(0, 12)
    .map((item, index) => {
      const qty = [item.quantity, item.packets ? `${item.packets} packet` : ""]
        .filter(Boolean)
        .join(", ");
      return `${index + 1}. ${clean(item.product_name || item.name)}${qty ? ` (${qty})` : ""}`;
    })
    .join("\n");

  return [
    "New JFAM order",
    `Order: ${clean(order.id)}`,
    `Customer: ${clean(order.customer_name) || "Customer"}`,
    `Mobile: ${clean(order.customer_phone) || "-"}`,
    `Payment: ${clean(order.payment_mode) || "-"}`,
    `Total: Rs. ${Math.round(Number(order.total_amount) || 0)}`,
    "",
    itemLines || "Items: not available"
  ].join("\n");
}

serve(async req => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") || "";
  const authHeader = req.headers.get("Authorization") || "";
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } }
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }

  const payload = await req.json() as OrderPayload;
  const orderId = clean(payload.orderId);
  if (!orderId || orderId.length > 128) {
    return new Response(JSON.stringify({ error: "Valid orderId required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }

  // Never notify from browser-provided totals, items, or customer details.
  // RLS scopes this lookup to the authenticated order owner.
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select("id, payment_mode, total_amount, customer_name, customer_phone, order_items(product_name, quantity, packets, price, plan, slot)")
    .eq("id", orderId)
    .maybeSingle();

  if (orderError || !order) {
    return new Response(JSON.stringify({ error: "Order not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
  const token = Deno.env.get("WHATSAPP_ACCESS_TOKEN");
  const phoneNumberId = Deno.env.get("WHATSAPP_PHONE_NUMBER_ID");
  const adminPhone = Deno.env.get("ADMIN_WHATSAPP_PHONE");

  if (!token || !phoneNumberId || !adminPhone) {
    return new Response(JSON.stringify({ error: "WhatsApp env vars missing" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }

  const message = buildMessage(order as StoredOrder);
  const response = await fetch(`https://graph.facebook.com/v20.0/${phoneNumberId}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to: adminPhone,
      type: "text",
      text: {
        preview_url: false,
        body: message
      }
    })
  });

  const result = await response.json();
  if (!response.ok) {
    return new Response(JSON.stringify({ error: "WhatsApp send failed", detail: result }), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }

  return new Response(JSON.stringify({ ok: true, detail: result }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" }
  });
});
