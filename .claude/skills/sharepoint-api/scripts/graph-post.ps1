# ============================================================================
# graph-post.ps1 — Authenticated Microsoft Graph POST request
# ============================================================================
# Usage:  .\graph-post.ps1 "/v1.0/sites/{siteId}/lists" '{"displayName":"MyList"}'
#         .\graph-post.ps1 "/v1.0/me/sendMail" '{"message":{...}}'
#         .\graph-post.ps1 "/v1.0/sites/{siteId}/lists/{listId}" '{"displayName":"Renamed"}' PATCH
#
# Optional 3rd argument overrides the HTTP method (PATCH, PUT, DELETE).
#
# Requires: GRAPH_TOKEN (set via: . .\sp-auth-wrapper.ps1 <tenant>)
# Outputs:  JSON response to stdout
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Endpoint,

    [Parameter(Mandatory = $true, Position = 1)]
    [AllowEmptyString()]
    [string]$Body,

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$Method = "POST"
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

$invokeParams = @{
    Uri         = $url
    Method      = $Method
    Headers     = $headers
    ContentType = "application/json"
}

if (-not [string]::IsNullOrWhiteSpace($Body)) {
    $invokeParams["Body"] = $Body
}

try {
    $response = Invoke-RestMethod @invokeParams
    if ($null -ne $response) {
        $response | ConvertTo-Json -Depth 20
    }
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "HTTP $statusCode on $Method $url"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
