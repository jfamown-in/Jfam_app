#!/usr/bin/env node
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname } from 'node:path';

function redact(value = '') {
  return String(value)
    .replace(/eyJ[A-Za-z0-9._-]+/g, '[redacted-jwt]')
    .replace(/([?&](?:apikey|token|key)=)[^&]+/gi, '$1[redacted]')
    .replace(/(Bearer\s+)[A-Za-z0-9._-]+/gi, '$1[redacted]');
}

async function readSupabaseConfig() {
  const source = await readFile(new URL('../Supabase.js', import.meta.url), 'utf8');
  const url = process.env.JFAM_SUPABASE_URL || source.match(/SUPABASE_URL\s*=\s*['"]([^'"]+)['"]/)?.[1];
  const key = process.env.JFAM_SUPABASE_ANON_KEY || source.match(/SUPABASE_KEY\s*=\s*['"]([^'"]+)['"]/)?.[1];
  if (!url || !key) throw new Error('Supabase URL or anon key missing');
  return { url: url.replace(/\/$/, ''), key };
}

function summarizeOpenApi(openapi) {
  const definitions = openapi?.definitions || openapi?.components?.schemas || {};
  return Object.fromEntries(
    Object.entries(definitions)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, schema]) => [
        name,
        {
          required: schema.required || [],
          properties: Object.fromEntries(
            Object.entries(schema.properties || {})
              .sort(([a], [b]) => a.localeCompare(b))
              .map(([column, meta]) => [column, {
                type: meta.type || meta.format || 'unknown',
                format: meta.format,
                description: meta.description,
              }])
          ),
        },
      ])
  );
}

const PUBLIC_CONTRACT = {
  product_catalog: ['product_name', 'category', 'description', 'image_url', 'display_price_text', 'unit_label', 'default_price', 'monthly_price', 'fifteen_day_price', 'weekly_price', 'one_time_price', 'custom_price', 'is_available', 'availability_message'],
  saved_addresses: ['local_id', 'name', 'mobile', 'pin', 'house', 'street', 'town', 'city', 'state', 'created_at'],
  orders: ['id', 'ordered_at', 'payment_mode', 'status', 'delivery_status', 'customer_name', 'customer_phone', 'customer_email', 'address', 'delivery_address', 'delivery_address_id', 'customer_type', 'order_category', 'cod_fee', 'total_amount'],
  order_items: ['order_id', 'item_index', 'product_name', 'price', 'image_url', 'quantity', 'packets', 'start_date', 'end_date', 'slot', 'plan', 'cancelled', 'cancelled_at', 'delivery_controls', 'delivery_controls_summary'],
};

async function probePublicContract(url, key) {
  const tables = {};
  for (const [table, columns] of Object.entries(PUBLIC_CONTRACT)) {
    const select = columns.join(',');
    const response = await fetch(`${url}/rest/v1/${table}?select=${encodeURIComponent(select)}&limit=0`, {
      headers: { apikey: key, authorization: `Bearer ${key}`, accept: 'application/json' },
    });
    const body = await response.text();
    tables[table] = {
      status: response.status,
      reachableWithAnon: response.ok || [401, 403].includes(response.status),
      columns,
      error: response.ok ? undefined : redact(body.slice(0, 240)),
    };
  }
  return tables;
}

async function main() {
  const { url, key } = await readSupabaseConfig();
  let baseline;
  const response = await fetch(`${url}/rest/v1/`, {
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      accept: 'application/openapi+json',
    },
  });
  const text = await response.text();

  if (response.ok) {
    const openapi = JSON.parse(text);
    baseline = {
      capturedAt: new Date().toISOString(),
      projectHost: new URL(url).hostname,
      source: 'Supabase REST OpenAPI using public anon key',
      tables: summarizeOpenApi(openapi),
    };
  } else {
    baseline = {
      capturedAt: new Date().toISOString(),
      projectHost: new URL(url).hostname,
      source: `Supabase anon contract probe because OpenAPI returned HTTP ${response.status}`,
      tables: await probePublicContract(url, key),
    };
  }

  const output = new URL('../docs/supabase-schema-baseline.json', import.meta.url);
  await mkdir(dirname(output.pathname), { recursive: true });
  await writeFile(output, `${JSON.stringify(baseline, null, 2)}\n`);
  console.log(JSON.stringify({ ok: true, output: 'docs/supabase-schema-baseline.json', tableCount: Object.keys(baseline.tables).length, source: baseline.source }, null, 2));
}

main().catch(error => {
  console.error(JSON.stringify({ ok: false, error: redact(error.message) }, null, 2));
  process.exitCode = 1;
});
