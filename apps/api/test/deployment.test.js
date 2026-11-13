import { test } from 'node:test';
import assert from 'node:assert/strict';
import { appOrigin, allowedOrigins } from '../src/lib/deployment.js';

test('QR links use the configured public origin rather than a private binding', () => {
  assert.equal(appOrigin({ APP_URL: 'https://consultoria.example/', WEB_URL: 'https://private.internal' }), 'https://consultoria.example');
});

test('deployment URL supplies the public origin when APP_URL is not configured', () => {
  assert.equal(appOrigin({ VERCEL_URL: 'preview.vercel.app' }), 'https://preview.vercel.app');
  assert.equal(appOrigin({}), 'http://localhost:5173');
});

test('CORS accepts the configured domain and the current deployment', () => {
  assert.deepEqual(allowedOrigins({ APP_URL: 'https://consultoria.example', VERCEL_URL: 'preview.vercel.app' }), ['https://consultoria.example', 'https://preview.vercel.app']);
});

test('public origins cannot use credentials or non-HTTP schemes', () => {
  for (const APP_URL of ['javascript:alert(1)', 'https://user:password@example.com']) {
    assert.throws(() => appOrigin({ APP_URL }));
  }
});
