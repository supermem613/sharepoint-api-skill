#!/usr/bin/env node
// ============================================================================
// sp-get.js — Authenticated SharePoint REST GET request
// ============================================================================
// Usage:  node sp-get.js "/_api/web/lists"
//
// Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
// Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
// Set via: source ./sp-auth-wrapper.sh  (bash)
//          . .\sp-auth-wrapper.ps1      (PowerShell)
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const endpoint = process.argv[2];

if (!endpoint) {
  process.stderr.write('ERROR: Missing endpoint.\n');
  process.stderr.write('Usage: node sp-get.js "/_api/web/lists"\n');
  process.exit(1);
}

const SP_SITE = process.env.SP_SITE;
if (!SP_SITE) {
  process.stderr.write('ERROR: SP_SITE is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com\n');
  process.exit(1);
}

const SP_TOKEN = process.env.SP_TOKEN;
const SP_COOKIES = process.env.SP_COOKIES;
if (!SP_TOKEN && !SP_COOKIES) {
  process.stderr.write('ERROR: Neither SP_TOKEN nor SP_COOKIES is set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com\n');
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
