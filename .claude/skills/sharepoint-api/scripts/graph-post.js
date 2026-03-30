#!/usr/bin/env node
// ============================================================================
// graph-post.js — Authenticated Microsoft Graph POST request
// ============================================================================
// Usage:  node graph-post.js "/v1.0/sites/{siteId}/lists" '{"displayName":"MyList"}'
//         node graph-post.js "/v1.0/me/sendMail" '{"message":{...}}'
//         node graph-post.js "/v1.0/sites/{siteId}/lists/{listId}" '{"displayName":"Renamed"}' PATCH
//         node graph-post.js "/v1.0/drives/{driveId}/items/{itemId}" '' DELETE
//
// Optional 3rd argument overrides the HTTP method (PATCH, PUT, DELETE).
//
// Requires: GRAPH_TOKEN
// Auth is auto-loaded from ~/.sharepoint-api-skill/auth.json or env vars.
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const { GRAPH_TOKEN } = require('./sp-env');

const endpoint = process.argv[2];
const body = process.argv[3] ?? '';
const method = (process.argv[4] ?? 'POST').toUpperCase();

if (!endpoint || process.argv.length < 4) {
  process.stderr.write('ERROR: Missing arguments.\n');
  process.stderr.write('Usage: node graph-post.js "/v1.0/..." \'{json_body}\' [METHOD_OVERRIDE]\n');
  process.exit(1);
}

if (!GRAPH_TOKEN) {
  process.stderr.write('ERROR: GRAPH_TOKEN is not set. Set GRAPH_TOKEN env var or add to ~/.sharepoint-api-skill/auth.json\n');
  process.exit(1);
}

const url = `https://graph.microsoft.com${endpoint}`;
const headers = {
  'Authorization': `Bearer ${GRAPH_TOKEN}`,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

const fetchOpts = { method, headers };
if (body) {
  fetchOpts.body = body;
}

(async () => {
  try {
    const res = await fetch(url, fetchOpts);
    const resBody = await res.text();

    if (res.ok) {
      if (resBody) {
        process.stdout.write(resBody + '\n');
      }
    } else {
      process.stderr.write(`ERROR: HTTP ${res.status} on ${method} ${url}\n`);
      process.stderr.write(resBody + '\n');
      process.exit(1);
    }
  } catch (err) {
    process.stderr.write(`ERROR: ${err.message}\n`);
    process.exit(1);
  }
})();
