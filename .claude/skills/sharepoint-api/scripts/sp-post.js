#!/usr/bin/env node
// ============================================================================
// sp-post.js — Authenticated SharePoint REST POST request
// ============================================================================
// Usage:  node sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"MyList"}'
//         node sp-post.js "/_api/web/lists/getbytitle('MyList')" '{"Title":"Renamed"}' PATCH
//         node sp-post.js "/_api/web/lists/getbytitle('MyList')" '' DELETE
//
// Automatically fetches the request digest from /_api/contextinfo.
// Optional 3rd argument overrides the HTTP method (PATCH, PUT, MERGE, DELETE).
//
// Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
// Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
// Auth is auto-loaded from ~/.sharepoint-api-skill/auth.json or env vars.
// Outputs:  JSON response to stdout
// ============================================================================
'use strict';

const { SP_SITE, SP_TOKEN, SP_COOKIES } = require('./sp-env');
const { spFetch } = require('./sp-fetch');

let endpoint = process.argv[2];
const body = process.argv[3] ?? '';
const methodOverride = process.argv[4] ?? '';

if (!endpoint || process.argv.length < 4) {
  process.stderr.write('ERROR: Missing arguments.\n');
  process.stderr.write('Usage: node sp-post.js "_api/..." \'{json_body}\' [METHOD_OVERRIDE]\n');
  process.exit(1);
}

// Accept endpoints with or without leading slash
if (!endpoint.startsWith('/')) endpoint = '/' + endpoint;

if (!SP_SITE) {
  process.stderr.write('ERROR: SP_SITE is not set. Run: node scripts/sp-auth.js contoso.sharepoint.com/sites/mysite\n');
  process.exit(1);
}

if (!SP_TOKEN && !SP_COOKIES) {
  process.stderr.write('ERROR: No auth credentials. Run: node scripts/sp-auth.js contoso.sharepoint.com/sites/mysite\n');
  process.exit(1);
}

function authHeaders() {
  if (SP_TOKEN) return { 'Authorization': `Bearer ${SP_TOKEN}` };
  return { 'Cookie': SP_COOKIES };
}

async function fetchDigest() {
  const res = await spFetch(`${SP_SITE}/_api/contextinfo`, {
    method: 'POST',
    headers: {
      ...authHeaders(),
      'Accept': 'application/json;odata=nometadata',
      'Content-Length': '0',
    },
  });

  if (!res.ok) {
    const text = await res.text();
    process.stderr.write(`ERROR: Failed to fetch request digest (HTTP ${res.status}).\n`);
    process.stderr.write(text + '\n');
    process.exit(1);
  }

  const json = await res.json();
  const digest = json.FormDigestValue;
  if (!digest) {
    process.stderr.write('ERROR: Could not parse request digest from contextinfo response.\n');
    process.exit(1);
  }
  return digest;
}

(async () => {
  try {
    const digest = await fetchDigest();
    const url = `${SP_SITE}${endpoint}`;

    const headers = {
      ...authHeaders(),
      'Accept': 'application/json;odata=nometadata',
      'Content-Type': 'application/json;odata=verbose',
      'X-RequestDigest': digest,
    };

    if (methodOverride) {
      headers['X-HTTP-Method'] = methodOverride;
      if (['MERGE', 'PATCH', 'DELETE'].includes(methodOverride.toUpperCase())) {
        headers['If-Match'] = '*';
      }
    }

    const fetchOpts = { method: 'POST', headers };
    if (body) {
      fetchOpts.body = body;
    }

    const res = await spFetch(url, fetchOpts);
    const resBody = await res.text();

    if (res.ok) {
      if (resBody) {
        process.stdout.write(resBody + '\n');
      }
    } else {
      process.stderr.write(`ERROR: HTTP ${res.status} on POST ${url}\n`);
      process.stderr.write(resBody + '\n');
      process.exit(1);
    }
  } catch (err) {
    process.stderr.write(err.message + '\n');
    process.exit(1);
  }
})();
