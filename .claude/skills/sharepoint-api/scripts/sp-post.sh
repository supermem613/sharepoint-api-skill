#!/bin/bash
set -euo pipefail
# ============================================================================
# sp-post.sh — Authenticated SharePoint REST POST request
# ============================================================================
# Usage:  ./sp-post.sh "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"MyList"}'
#         ./sp-post.sh "/_api/web/lists/getbytitle('MyList')" '{"Title":"Renamed"}' PATCH
#         ./sp-post.sh "/_api/web/lists/getbytitle('MyList')" '' DELETE
#
# Automatically fetches the request digest from /_api/contextinfo.
# Optional 3rd argument overrides the HTTP method (PATCH, PUT, MERGE, DELETE).
#
# Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
# Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
# Set via: source ./sp-auth-wrapper.sh
# Outputs:  JSON response to stdout
# ============================================================================

if [[ $# -lt 2 ]]; then
    echo "ERROR: Missing arguments." >&2
    echo "Usage: ./sp-post.sh \"/_api/...\" '{json_body}' [METHOD_OVERRIDE]" >&2
    exit 1
fi

if [[ -z "${SP_SITE:-}" ]]; then
    echo "ERROR: SP_SITE is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com" >&2
    exit 1
fi
if [[ -z "${SP_TOKEN:-}" && -z "${SP_COOKIES:-}" ]]; then
    echo "ERROR: Neither SP_TOKEN nor SP_COOKIES is set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com" >&2
    exit 1
fi

ENDPOINT="$1"
BODY="$2"
METHOD_OVERRIDE="${3:-}"

URL="${SP_SITE}${ENDPOINT}"

# Determine auth header
AUTH_HEADER=""
if [[ -n "${SP_TOKEN:-}" ]]; then
    AUTH_HEADER="Authorization: Bearer ${SP_TOKEN}"
elif [[ -n "${SP_COOKIES:-}" ]]; then
    AUTH_HEADER="Cookie: ${SP_COOKIES}"
fi

# -- Fetch request digest (required for SP REST write operations) ----------
DIGEST_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json;odata=nometadata" \
    -H "Content-Length: 0" \
    "${SP_SITE}/_api/contextinfo")

DIGEST_BODY=$(echo "$DIGEST_RESPONSE" | sed '$d')
DIGEST_CODE=$(echo "$DIGEST_RESPONSE" | tail -n1)

if [[ "$DIGEST_CODE" -lt 200 || "$DIGEST_CODE" -ge 300 ]]; then
    echo "ERROR: Failed to fetch request digest (HTTP ${DIGEST_CODE})." >&2
    echo "$DIGEST_BODY" >&2
    exit 1
fi

# Extract FormDigestValue — try jq first, fall back to grep/sed (no python dependency)
if command -v jq &>/dev/null; then
    REQUEST_DIGEST=$(echo "$DIGEST_BODY" | jq -r '.FormDigestValue')
else
    # Portable fallback: extract the value between "FormDigestValue":" and the next "
    REQUEST_DIGEST=$(echo "$DIGEST_BODY" | sed 's/.*"FormDigestValue":"\([^"]*\)".*/\1/')
fi

if [[ -z "$REQUEST_DIGEST" ]]; then
    echo "ERROR: Could not parse request digest from contextinfo response." >&2
    exit 1
fi

# -- Build curl arguments --------------------------------------------------
CURL_ARGS=(
    -s -w "\n%{http_code}"
    -X POST
    -H "$AUTH_HEADER"
    -H "Accept: application/json;odata=verbose"
    -H "Content-Type: application/json;odata=verbose"
    -H "X-RequestDigest: ${REQUEST_DIGEST}"
)

if [[ -n "$METHOD_OVERRIDE" ]]; then
    CURL_ARGS+=(-H "X-HTTP-Method: ${METHOD_OVERRIDE}")
    if [[ "$METHOD_OVERRIDE" == "MERGE" || "$METHOD_OVERRIDE" == "PATCH" || "$METHOD_OVERRIDE" == "DELETE" ]]; then
        CURL_ARGS+=(-H "If-Match: *")
    fi
fi

if [[ -n "$BODY" ]]; then
    CURL_ARGS+=(-d "$BODY")
else
    CURL_ARGS+=(-H "Content-Length: 0")
fi

HTTP_RESPONSE=$(curl "${CURL_ARGS[@]}" "$URL")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    # Some operations (DELETE, 204) return empty bodies
    if [[ -n "$HTTP_BODY" ]]; then
        echo "$HTTP_BODY"
    fi
else
    echo "ERROR: HTTP ${HTTP_CODE} on POST ${URL}" >&2
    echo "$HTTP_BODY" >&2
    exit 1
fi
