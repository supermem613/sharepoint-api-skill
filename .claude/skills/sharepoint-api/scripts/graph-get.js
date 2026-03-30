#!/usr/bin/env node
// ============================================================================
// graph-get.js — Authenticated Microsoft Graph GET request
// ============================================================================
// Usage:  node graph-get.js "/v1.0/sites/{siteId}/lists"
//         node graph-get.js "/v1.0/me"
//         node graph-get.js "/beta/sites?search=contoso"
//
// Requires: GRAPH_TOKEN (set via: source ./sp-auth-wrapper.sh <tenant>)
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const endpoint = process.argv[2];

if (!endpoint) {
  process.stderr.write('ERROR: Missing endpoint.\n');
  process.stderr.write('Usage: node graph-get.js "/v1.0/sites/{siteId}/lists"\n');
  process.exit(1);
}

const GRAPH_TOKEN = process.env.GRAPH_TOKEN;
if (!GRAPH_TOKEN) {
  process.stderr.write('ERROR: GRAPH_TOKEN is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com\n');
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
