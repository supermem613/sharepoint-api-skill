#!/bin/bash
# ============================================================================
# sp-auth-wrapper.sh — Authenticate to SharePoint via Playwright
# ============================================================================
# Usage: source ./sp-auth-wrapper.sh contoso.sharepoint.com
#        source ./sp-auth-wrapper.sh contoso.sharepoint.com --login
#        source ./sp-auth-wrapper.sh contoso.sharepoint.com --logout
#
# First run opens Edge for login (one-time). After that, auth is automatic.
# Sets: SP_COOKIES, SP_SITE, SP_TOKEN
# ============================================================================

# Prevent Git Bash (MSYS2) from converting arguments that look like Unix paths
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval $(node "$SCRIPT_DIR/sp-auth.js" "$@")
