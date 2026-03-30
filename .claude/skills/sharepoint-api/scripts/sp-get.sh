#!/bin/bash
set -euo pipefail
# ============================================================================
# sp-get.sh — Authenticated SharePoint REST GET request
# ============================================================================
# Usage:  ./sp-get.sh "/_api/web/lists"
#
# Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
# Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
# Set via: source ./sp-auth-wrapper.sh
# Outputs:  JSON response to stdout
# ============================================================================

if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing endpoint." >&2
    echo "Usage: ./sp-get.sh \"/_api/web/lists\"" >&2
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
URL="${SP_SITE}${ENDPOINT}"

AUTH_HEADER=""
if [[ -n "${SP_TOKEN:-}" ]]; then
    AUTH_HEADER="Authorization: Bearer ${SP_TOKEN}"
elif [[ -n "${SP_COOKIES:-}" ]]; then
    AUTH_HEADER="Cookie: ${SP_COOKIES}"
fi

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json;odata=nometadata" \
    "$URL")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "$HTTP_BODY"
else
    echo "ERROR: HTTP ${HTTP_CODE} on GET ${URL}" >&2
    echo "$HTTP_BODY" >&2
    exit 1
fi
