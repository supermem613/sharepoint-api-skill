#!/usr/bin/env node
// ============================================================================
// sp-fetch.js — Shared fetch wrapper with retry and diagnostic error messages
// ============================================================================
// Usage:  const { spFetch } = require('./sp-fetch');
//         const res = await spFetch(url, { method: 'GET', headers });
//
// Drop-in replacement for global fetch() that adds:
//   - Retry (2 attempts) on transient network errors
//   - Walks err.cause / err.errors chains to find the real error code
//   - Produces actionable multi-line error messages with hints
//
// Zero dependencies — uses only the global fetch (Node 18+).
// ============================================================================
'use strict';

const RETRYABLE = new Set([
  'ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED',
  'UND_ERR_CONNECT_TIMEOUT', 'UND_ERR_SOCKET',
]);
const MAX_RETRIES = 2;

/** Walk cause/errors chain to find the root network error code. */
function extractCode(err) {
  let cur = err;
  while (cur) {
    if (cur.code) return cur.code;
    if (cur.cause) { cur = cur.cause; continue; }
    if (cur.errors && cur.errors.length) { cur = cur.errors[0]; continue; }
    break;
  }
  return null;
}

/** Build a multi-line diagnostic from a network error. */
function formatError(err) {
  const code = extractCode(err);
  const lines = [`ERROR: fetch failed — ${err.message}`];
  if (code) lines.push(`  Code: ${code}`);

  let cause = err.cause;
  let depth = 0;
  while (cause && depth < 3) {
    lines.push(`  Cause: ${cause.message}${cause.code ? ` (${cause.code})` : ''}`);
    cause = cause.cause || (cause.errors && cause.errors[0]);
    depth++;
  }

  if (code === 'ETIMEDOUT' || code === 'UND_ERR_CONNECT_TIMEOUT') {
    lines.push('  Hint: Connection timed out. Check network connectivity and DNS.');
  } else if (code === 'ECONNREFUSED') {
    lines.push('  Hint: Connection refused. Verify the site URL is correct.');
  } else if (code === 'ENOTFOUND') {
    lines.push('  Hint: DNS lookup failed. Check hostname and network connectivity.');
  }

  return lines.join('\n');
}

/** fetch() with retry on transient errors and enriched diagnostics. */
async function spFetch(url, options) {
  let lastErr;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      return await fetch(url, options);
    } catch (err) {
      lastErr = err;
      const code = extractCode(err);
      if (!code || !RETRYABLE.has(code) || attempt === MAX_RETRIES) break;
      await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
  const enriched = new Error(formatError(lastErr));
  enriched.originalError = lastErr;
  throw enriched;
}

module.exports = { spFetch, formatError, extractCode };
