# ============================================================================
# graph-get.ps1 — Authenticated Microsoft Graph GET request
# ============================================================================
# Usage:  .\graph-get.ps1 "/v1.0/sites/{siteId}/lists"
#         .\graph-get.ps1 "/v1.0/me"
#         .\graph-get.ps1 "/beta/sites?search=contoso"
#
# Requires: GRAPH_TOKEN (set via: . .\sp-auth-wrapper.ps1 <tenant>)
# Outputs:  JSON response to stdout
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Endpoint
)

if ([string]::IsNullOrWhiteSpace($env:GRAPH_TOKEN)) {
    Write-Error "GRAPH_TOKEN is not set. Run: . .\sp-auth-wrapper.ps1 <tenant>.sharepoint.com"
    exit 1
}

$url = "https://graph.microsoft.com$Endpoint"
$headers = @{
    "Authorization" = "Bearer $env:GRAPH_TOKEN"
    "Accept"        = "application/json"
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
