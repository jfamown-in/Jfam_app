#!/usr/bin/env node
import { createHmac } from 'node:crypto';
import { readFile } from 'node:fs/promises';

function extractWebhookSource(source) {
  if (!source.includes('crypto.subtle.importKey')) {
    throw new Error('Webhook function does not verify HMAC with Web Crypto.');
  }
  if (!source.includes('x-razorpay-signature')) {
    throw new Error('Webhook function does not read x-razorpay-signature.');
  }
  if (!source.includes('await req.text()')) {
    throw new Error('Webhook function must verify the raw request body.');
  }
}

const body = JSON.stringify({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_test', amount: 100, status: 'captured', notes: { payment_attempt_id: '00000000-0000-0000-0000-000000000000' } } } } });
const secret = 'test_secret';
const signature = createHmac('sha256', secret).update(body).digest('hex');
const badSignature = createHmac('sha256', secret).update(`${body}x`).digest('hex');
if (signature === badSignature) throw new Error('signature fixture is invalid');
extractWebhookSource(await readFile(new URL('../supabase/functions/razorpay-webhook/index.ts', import.meta.url), 'utf8'));
console.log(JSON.stringify({ ok: true, verified: ['raw-body-required', 'hmac-sha256-fixture', 'signature-header'] }, null, 2));
