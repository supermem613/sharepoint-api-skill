#!/usr/bin/env node
// ============================================================================
// graph-get.js — Authenticated Microsoft Graph GET request
// ============================================================================
// Usage:  node graph-get.js "/v1.0/sites/{siteId}/lists"
//         node graph-get.js "/v1.0/me"
//         node graph-get.js "/beta/sites?search=contoso"
//
// Requires: GRAPH_TOKEN
// Auth is auto-loaded from ~/.sharepoint-api-skill/auth.json or env vars.
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const { GRAPH_TOKEN } = require('./sp-env');

const endpoint = process.argv[2];

if (!endpoint) {
  process.stderr.write('ERROR: Missing endpoint.\n');
  process.stderr.write('Usage: node graph-get.js "/v1.0/sites/{siteId}/lists"\n');
  process.exit(1);
}

if (!GRAPH_TOKEN) {
  process.stderr.write('ERROR: GRAPH_TOKEN is not set. Set GRAPH_TOKEN env var or add to ~/.sharepoint-api-skill/auth.json\n');
  process.exit(1);
}

const url = `https://graph.microsoft.com${endpoint}`;
const headers = {
  'Authorization': `Bearer ${GRAPH_TOKEN}`,
  'Accept': 'application/json',
};

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
