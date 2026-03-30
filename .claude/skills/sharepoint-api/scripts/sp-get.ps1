# ============================================================================
# sp-get.ps1 — Authenticated SharePoint REST GET request
# ============================================================================
# Usage:  .\sp-get.ps1 "/_api/web/lists"
#
# Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
# Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
# Set via: . .\sp-auth-wrapper.ps1
# Outputs:  JSON response to stdout
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Endpoint
)

if ([string]::IsNullOrWhiteSpace($env:SP_SITE)) {
    Write-Error "SP_SITE is not set. Run: . .\sp-auth-wrapper.ps1 <tenant>.sharepoint.com"
    exit 1
}
if ([string]::IsNullOrWhiteSpace($env:SP_TOKEN) -and [string]::IsNullOrWhiteSpace($env:SP_COOKIES)) {
    Write-Error "Neither SP_TOKEN nor SP_COOKIES is set. Run: . .\sp-auth-wrapper.ps1 <tenant>.sharepoint.com"
    exit 1
}

$url = "$env:SP_SITE$Endpoint"
$headers = @{
    "Accept" = "application/json;odata=nometadata"
}

if (-not [string]::IsNullOrWhiteSpace($env:SP_TOKEN)) {
    $headers["Authorization"] = "Bearer $env:SP_TOKEN"
}
elseif (-not [string]::IsNullOrWhiteSpace($env:SP_COOKIES)) {
    $headers["Cookie"] = $env:SP_COOKIES
}

try {
    $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
    $response | ConvertTo-Json -Depth 20
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "HTTP $statusCode on GET $url"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
