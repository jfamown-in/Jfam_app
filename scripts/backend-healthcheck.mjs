#!/usr/bin/env node
import { promises as dns } from 'node:dns';
import { readFile } from 'node:fs/promises';

const DEFAULT_RPCS = ['backend_healthcheck'];
const DEFAULT_EDGE_FUNCTIONS = [];
const TIMEOUT_MS = Number(process.env.JFAM_HEALTH_TIMEOUT_MS || 12000);

function splitList(value, fallback = []) {
  if (String(value || '').trim() === '-') return [];
  const values = String(value || '')
    .split(',')
    .map(item => item.trim())
    .filter(Boolean);
  return values.length ? values : fallback;
}

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

  if (!url || !key) {
    throw new Error('Supabase URL or anon key is missing. Set JFAM_SUPABASE_URL and JFAM_SUPABASE_ANON_KEY, or keep Supabase.js configured.');
  }

  return { url: url.replace(/\/$/, ''), key };
}

async function fetchWithTimeout(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    const body = await response.text().catch(() => '');
    return { status: response.status, ok: response.ok, body: body.slice(0, 500) };
  } finally {
    clearTimeout(timer);
  }
}

function assertStatus(name, result, allowedStatuses) {
  if (!allowedStatuses.includes(result.status)) {
    throw new Error(`${name} returned HTTP ${result.status}: ${redact(result.body).slice(0, 180)}`);
  }
}

async function checkDns(projectUrl) {
  const host = new URL(projectUrl).hostname;
  await dns.lookup(host);
  return { name: 'dns', host };
}

async function checkAuth(projectUrl, anonKey) {
  const result = await fetchWithTimeout(`${projectUrl}/auth/v1/settings`, {
    headers: { apikey: anonKey, authorization: `Bearer ${anonKey}` },
  });
  assertStatus('auth settings', result, [200]);
  return { name: 'auth', status: result.status };
}

async function checkRestGateway(projectUrl, anonKey) {
  const root = await fetchWithTimeout(`${projectUrl}/rest/v1/`, {
    method: 'OPTIONS',
    headers: { apikey: anonKey, authorization: `Bearer ${anonKey}` },
  });
  assertStatus('REST gateway', root, [200, 204]);

  const tableName = process.env.JFAM_REST_HEALTH_TABLE || 'product_catalog';
  const table = await fetchWithTimeout(`${projectUrl}/rest/v1/${encodeURIComponent(tableName)}?select=*&limit=1`, {
    method: 'HEAD',
    headers: { apikey: anonKey, authorization: `Bearer ${anonKey}` },
  });
  assertStatus(`REST table ${tableName}`, table, [200, 206]);

  return { name: 'rest', status: table.status, table: tableName };
}

async function checkRpc(projectUrl, anonKey, rpcName) {
  const result = await fetchWithTimeout(`${projectUrl}/rest/v1/rpc/${encodeURIComponent(rpcName)}`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${anonKey}`,
      'content-type': 'application/json',
      accept: 'application/json',
    },
    body: '{}',
  });
  assertStatus(`RPC ${rpcName}`, result, [200, 204]);
  return { name: `rpc:${rpcName}`, status: result.status };
}

async function checkEdgeFunction(projectUrl, anonKey, functionName) {
  const result = await fetchWithTimeout(`${projectUrl}/functions/v1/${encodeURIComponent(functionName)}`, {
    method: 'OPTIONS',
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${anonKey}`,
      origin: 'https://jfam-healthcheck.local',
      'access-control-request-method': 'POST',
      'access-control-request-headers': 'authorization,content-type,apikey',
    },
  });

  if (result.status === 404) {
    throw new Error(`Edge Function ${functionName} is not available: HTTP 404`);
  }

  return { name: `edge:${functionName}`, status: result.status };
}

async function main() {
  const { url, key } = await readSupabaseConfig();
  const requiredRpcs = splitList(process.env.JFAM_REQUIRED_RPCS, DEFAULT_RPCS);
  const edgeFunctions = splitList(process.env.JFAM_EDGE_FUNCTIONS, DEFAULT_EDGE_FUNCTIONS);

  const checks = [];
  checks.push(await checkDns(url));
  checks.push(await checkAuth(url, key));
  checks.push(await checkRestGateway(url, key));

  for (const rpc of requiredRpcs) checks.push(await checkRpc(url, key, rpc));
  for (const fn of edgeFunctions) checks.push(await checkEdgeFunction(url, key, fn));

  console.log(JSON.stringify({ ok: true, projectHost: new URL(url).hostname, checkedAt: new Date().toISOString(), checks }, null, 2));
}

main().catch(error => {
  console.error(JSON.stringify({ ok: false, checkedAt: new Date().toISOString(), error: redact(error.message) }, null, 2));
  process.exitCode = 1;
});
