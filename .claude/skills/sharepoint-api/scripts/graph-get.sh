#!/bin/bash
set -euo pipefail
# ============================================================================
# graph-get.sh — Authenticated Microsoft Graph GET request
# ============================================================================
# Usage:  ./graph-get.sh "/v1.0/sites/{siteId}/lists"
#         ./graph-get.sh "/v1.0/me"
#         ./graph-get.sh "/beta/sites?search=contoso"
#
# Requires: GRAPH_TOKEN (set via: source ./sp-auth-wrapper.sh <tenant>)
# Outputs:  JSON response to stdout
# ============================================================================

if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing endpoint." >&2
    echo "Usage: ./graph-get.sh \"/v1.0/sites/{siteId}/lists\"" >&2
    exit 1
fi

if [[ -z "${GRAPH_TOKEN:-}" ]]; then
    echo "ERROR: GRAPH_TOKEN is not set. Run: source ./sp-auth-wrapper.sh <tenant>.sharepoint.com" >&2
    exit 1
fi

ENDPOINT="$1"
URL="https://graph.microsoft.com${ENDPOINT}"

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${GRAPH_TOKEN}" \
    -H "Accept: application/json" \
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
