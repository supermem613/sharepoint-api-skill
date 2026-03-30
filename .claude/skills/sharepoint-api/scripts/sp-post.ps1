# ============================================================================
# sp-post.ps1 — Authenticated SharePoint REST POST request
# ============================================================================
# Usage:  .\sp-post.ps1 "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"MyList"}'
#         .\sp-post.ps1 "/_api/web/lists/getbytitle('MyList')" '{"Title":"Renamed"}' PATCH
#         .\sp-post.ps1 "/_api/web/lists/getbytitle('MyList')" '' DELETE
#
# Automatically fetches the request digest from /_api/contextinfo.
# Optional 3rd argument overrides the HTTP method (PATCH, PUT, MERGE, DELETE).
#
# Auth: Uses SP_TOKEN (bearer) or SP_COOKIES (Playwright browser cookies).
# Requires: SP_SITE + one of (SP_TOKEN, SP_COOKIES)
# Set via: . .\sp-auth-wrapper.ps1
# Outputs:  JSON response to stdout
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Endpoint,

    [Parameter(Mandatory = $true, Position = 1)]
    [AllowEmptyString()]
    [string]$Body,

    [Parameter(Mandatory = $false, Position = 2)]
    [string]$MethodOverride = ""
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

# -- Fetch request digest --------------------------------------------------
$digestHeaders = @{
    "Accept" = "application/json;odata=nometadata"
}
if (-not [string]::IsNullOrWhiteSpace($env:SP_TOKEN)) {
    $digestHeaders["Authorization"] = "Bearer $env:SP_TOKEN"
} elseif (-not [string]::IsNullOrWhiteSpace($env:SP_COOKIES)) {
    $digestHeaders["Cookie"] = $env:SP_COOKIES
}

try {
    $digestResponse = Invoke-RestMethod -Uri "$env:SP_SITE/_api/contextinfo" -Method Post -Headers $digestHeaders -Body "" -ContentType "application/json"
    $requestDigest = $digestResponse.FormDigestValue
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Error "Failed to fetch request digest (HTTP $statusCode)."
    Write-Error $_.ErrorDetails.Message
    exit 1
}

if ([string]::IsNullOrWhiteSpace($requestDigest)) {
    Write-Error "Could not parse request digest from contextinfo response."
    exit 1
}

# -- Build request ----------------------------------------------------------
$headers = @{
    "Accept"          = "application/json;odata=verbose"
    "X-RequestDigest" = $requestDigest
}

if (-not [string]::IsNullOrWhiteSpace($env:SP_TOKEN)) {
    $headers["Authorization"] = "Bearer $env:SP_TOKEN"
} elseif (-not [string]::IsNullOrWhiteSpace($env:SP_COOKIES)) {
    $headers["Cookie"] = $env:SP_COOKIES
}

if (-not [string]::IsNullOrWhiteSpace($MethodOverride)) {
    $headers["X-HTTP-Method"] = $MethodOverride
    if ($MethodOverride -in @("MERGE", "PATCH", "DELETE")) {
        $headers["If-Match"] = "*"
    }
}

$invokeParams = @{
    Uri         = $url
    Method      = "Post"
    Headers     = $headers
    ContentType = "application/json;odata=verbose"
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
    Write-Error "HTTP $statusCode on POST $url"
    Write-Error $_.ErrorDetails.Message
    exit 1
}
