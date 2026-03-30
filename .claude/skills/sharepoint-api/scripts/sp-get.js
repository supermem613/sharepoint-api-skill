#!/usr/bin/env node
// ============================================================================
// sp-get.js — Authenticated SharePoint REST GET request
// ============================================================================
// Usage:  node sp-get.js "/_api/web/lists"
//
// Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
// Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
// Auth is auto-loaded from ~/.sharepoint-api-skill/auth.json or env vars.
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const { SP_SITE, SP_TOKEN, SP_COOKIES } = require('./sp-env');

const endpoint = process.argv[2];

if (!endpoint) {
  process.stderr.write('ERROR: Missing endpoint.\n');
  process.stderr.write('Usage: node sp-get.js "/_api/web/lists"\n');
  process.exit(1);
}

if (!SP_SITE) {
  process.stderr.write('ERROR: SP_SITE is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com\n');
  process.exit(1);
}

if (!SP_TOKEN && !SP_COOKIES) {
  process.stderr.write('ERROR: No auth credentials. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com\n');
  process.exit(1);
}

const url = `${SP_SITE}${endpoint}`;
const headers = { 'Accept': 'application/json;odata=nometadata' };

if (SP_TOKEN) {
  headers['Authorization'] = `Bearer ${SP_TOKEN}`;
} else {
  headers['Cookie'] = SP_COOKIES;
}

(async () => {
  try {
    const res = await fetch(url, { method: 'GET', headers });
    const body = await res.text();

    if (res.ok) {
      process.stdout.write(body + '\n');
    } else {
      process.stderr.write(`ERROR: HTTP ${res.status} on GET ${url}\n`);
      process.stderr.write(body + '\n');
      process.exit(1);
    }
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }
})();
