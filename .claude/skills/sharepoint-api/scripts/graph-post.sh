#!/bin/bash
set -euo pipefail
# ============================================================================
# graph-post.sh — Authenticated Microsoft Graph POST request
# ============================================================================
# Usage:  ./graph-post.sh "/v1.0/sites/{siteId}/lists" '{"displayName":"MyList"}'
#         ./graph-post.sh "/v1.0/me/sendMail" '{"message":{...}}'
#         ./graph-post.sh "/v1.0/sites/{siteId}/lists/{listId}" '{"displayName":"Renamed"}' PATCH
#
# Optional 3rd argument overrides the HTTP method (PATCH, PUT, DELETE).
#
# Requires: GRAPH_TOKEN (set via: source ./sp-auth-wrapper.sh <tenant>)
# Outputs:  JSON response to stdout
# ============================================================================

if [[ $# -lt 2 ]]; then
    echo "ERROR: Missing arguments." >&2
    echo "Usage: ./graph-post.sh \"/v1.0/...\" '{json_body}' [METHOD_OVERRIDE]" >&2
    exit 1
fi

if [[ -z "${GRAPH_TOKEN:-}" ]]; then
    echo "ERROR: GRAPH_TOKEN is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com" >&2
    exit 1
fi

ENDPOINT="$1"
BODY="$2"
METHOD="${3:-POST}"

URL="https://graph.microsoft.com${ENDPOINT}"

CURL_ARGS=(
    -s -w "\n%{http_code}"
    -X "$METHOD"
    -H "Authorization: Bearer ${GRAPH_TOKEN}"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
)

if [[ -n "$BODY" ]]; then
    CURL_ARGS+=(-d "$BODY")
else
    CURL_ARGS+=(-H "Content-Length: 0")
fi

HTTP_RESPONSE=$(curl "${CURL_ARGS[@]}" "$URL")

HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    if [[ -n "$HTTP_BODY" ]]; then
        echo "$HTTP_BODY"
    fi
else
    echo "ERROR: HTTP ${HTTP_CODE} on ${METHOD} ${URL}" >&2
    echo "$HTTP_BODY" >&2
    exit 1
fi
