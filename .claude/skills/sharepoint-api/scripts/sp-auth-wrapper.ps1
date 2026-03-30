# ============================================================================
# sp-auth-wrapper.ps1 — Authenticate to SharePoint via Playwright
# ============================================================================
# Usage: . .\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite
#        . .\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite -Login
#        . .\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite -Logout
#
# First run opens Edge for login (one-time). After that, auth is automatic.
# Sets: SP_COOKIES, SP_SITE, SP_TOKEN
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TenantHost,

    [switch]$Login,
    [switch]$Logout
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$nodeArgs = @("$scriptDir\sp-auth.js", $TenantHost, "--ps1")
if ($Login) { $nodeArgs += "--login" }
if ($Logout) { $nodeArgs += "--logout" }
node @nodeArgs | Invoke-Expression
