# ============================================================================
# test-scripts.ps1 — Offline validation of sharepoint-api-skill scripts
# ============================================================================
# Runs without Pester, network calls, or external dependencies.
# Usage:  pwsh ./tests/test-scripts.ps1
# Exit:   0 = all passed, non-zero = failure count
# ============================================================================

$ErrorActionPreference = "Continue"

$scriptDir = Join-Path $PSScriptRoot ".." ".claude" "skills" "sharepoint-api" "scripts"
$scriptDir = (Resolve-Path $scriptDir).Path

$pass = 0; $fail = 0; $total = 0

function Test($name, [scriptblock]$block) {
    $script:total++
    try {
        & $block
        $script:pass++
        Write-Host "  ✅ $name"
    }
    catch {
        $script:fail++
        Write-Host "  ❌ $name — $_" -ForegroundColor Red
    }
}

# Helper: run a script in a child pwsh process with a clean environment.
# Returns @{ ExitCode; Stderr; Stdout }
function Invoke-Script {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [hashtable]$EnvVars = @{}
    )
    # Build env-set preamble
    $envLines = foreach ($kv in $EnvVars.GetEnumerator()) {
        if ($null -eq $kv.Value) {
            "`$env:$($kv.Key) = `$null"
        } else {
            "`$env:$($kv.Key) = '$($kv.Value)'"
        }
    }
    $envBlock = ($envLines -join "; ")
    if ($envBlock) { $envBlock += "; " }

    $argStr = ($Arguments | ForEach-Object { "'$_'" }) -join " "

    $cmd = "${envBlock}& '$ScriptPath' $argStr"

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $proc = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile", "-NonInteractive", "-Command", $cmd `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        return @{
            ExitCode = $proc.ExitCode
            Stdout   = (Get-Content $stdoutFile -Raw -ErrorAction SilentlyContinue) ?? ""
            Stderr   = (Get-Content $stderrFile -Raw -ErrorAction SilentlyContinue) ?? ""
        }
    }
    finally {
        Remove-Item $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# 1. FILE EXISTS tests
# ============================================================================
Write-Host "`n📁 File existence" -ForegroundColor Cyan

$allScripts = @("sp-get.ps1", "sp-post.ps1", "graph-get.ps1", "graph-post.ps1", "sp-auth-wrapper.ps1")
foreach ($s in $allScripts) {
    Test "$s exists" {
        $path = Join-Path $scriptDir $s
        if (-not (Test-Path $path)) { throw "$s not found at $path" }
    }
}

# ============================================================================
# 2. PARAM BLOCK tests
# ============================================================================
Write-Host "`n📝 Has param block" -ForegroundColor Cyan

foreach ($s in $allScripts) {
    Test "$s has param() block" {
        $content = Get-Content (Join-Path $scriptDir $s) -Raw
        if ($content -notmatch '(?m)^\s*param\s*\(') { throw "$s missing param() block" }
    }
}

# ============================================================================
# 3. ERROR ON MISSING ARGS tests
# ============================================================================
Write-Host "`n🚫 Error on missing arguments" -ForegroundColor Cyan

# sp-get.ps1 — mandatory $Endpoint
Test "sp-get.ps1 fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.ps1") -EnvVars @{ SP_TOKEN = $null; SP_COOKIES = $null; SP_SITE = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

# sp-post.ps1 — mandatory $Endpoint + $Body
Test "sp-post.ps1 fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.ps1") -EnvVars @{ SP_TOKEN = $null; SP_COOKIES = $null; SP_SITE = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

# graph-get.ps1 — mandatory $Endpoint
Test "graph-get.ps1 fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.ps1") -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

# graph-post.ps1 — mandatory $Endpoint + $Body
Test "graph-post.ps1 fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.ps1") -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

# sp-auth-wrapper.ps1 — mandatory $TenantHost
Test "sp-auth-wrapper.ps1 fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-auth-wrapper.ps1")
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

# ============================================================================
# 4. ERROR ON MISSING ENV VARS tests
# ============================================================================
Write-Host "`n🔑 Error on missing environment variables" -ForegroundColor Cyan

# sp-get: needs SP_SITE + (SP_TOKEN or SP_COOKIES)
Test "sp-get.ps1 fails when SP_SITE is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.ps1") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = "fake"; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_SITE") { throw "Error should mention SP_SITE, got: $($r.Stderr)" }
}

Test "sp-get.ps1 fails when SP_TOKEN and SP_COOKIES are both missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.ps1") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = "https://test.sharepoint.com"; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_TOKEN|SP_COOKIES") { throw "Error should mention SP_TOKEN/SP_COOKIES, got: $($r.Stderr)" }
}

# sp-post: needs SP_SITE + (SP_TOKEN or SP_COOKIES)
Test "sp-post.ps1 fails when SP_SITE is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.ps1") -Arguments @("/_api/web/lists", '{}') `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = "fake"; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_SITE") { throw "Error should mention SP_SITE" }
}

Test "sp-post.ps1 fails when SP_TOKEN and SP_COOKIES are both missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.ps1") -Arguments @("/_api/web/lists", '{}') `
        -EnvVars @{ SP_SITE = "https://test.sharepoint.com"; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_TOKEN|SP_COOKIES") { throw "Error should mention SP_TOKEN/SP_COOKIES" }
}

# graph-get: needs GRAPH_TOKEN
Test "graph-get.ps1 fails when GRAPH_TOKEN is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.ps1") -Arguments @("/v1.0/me") `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "GRAPH_TOKEN") { throw "Error should mention GRAPH_TOKEN" }
}

# graph-post: needs GRAPH_TOKEN
Test "graph-post.ps1 fails when GRAPH_TOKEN is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.ps1") -Arguments @("/v1.0/me", '{}') `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "GRAPH_TOKEN") { throw "Error should mention GRAPH_TOKEN" }
}

# ============================================================================
# 5. HELPFUL ERROR MESSAGES (mention sp-auth)
# ============================================================================
Write-Host "`n💡 Helpful error messages reference sp-auth" -ForegroundColor Cyan

Test "sp-get.ps1 error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.ps1") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth, got: $($r.Stderr)" }
}

Test "sp-post.ps1 error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.ps1") -Arguments @("/_api/web", '{}') `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth" }
}

Test "graph-get.ps1 error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.ps1") -Arguments @("/v1.0/me") `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth" }
}

Test "graph-post.ps1 error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.ps1") -Arguments @("/v1.0/me", '{}') `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth" }
}

# ============================================================================
# 6. sp-auth.js: exists and has shebang
# ============================================================================
Write-Host "`n🔧 sp-auth.js validation" -ForegroundColor Cyan

Test "sp-auth.js exists" {
    $path = Join-Path $scriptDir "sp-auth.js"
    if (-not (Test-Path $path)) { throw "sp-auth.js not found at $path" }
}

Test "sp-auth.js has node shebang" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth.js") -Raw
    if ($content -notmatch 'node') { throw "sp-auth.js should reference node" }
}

Test "sp-auth.js uses playwright" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth.js") -Raw
    if ($content -notmatch 'playwright') { throw "sp-auth.js should use playwright" }
}

Test "sp-auth.js handles --login flag" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth.js") -Raw
    if ($content -notmatch '--login') { throw "sp-auth.js should handle --login flag" }
}

Test "sp-auth.js handles --logout flag" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth.js") -Raw
    if ($content -notmatch '--logout') { throw "sp-auth.js should handle --logout flag" }
}

Test "sp-auth.js handles --ps1 flag" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth.js") -Raw
    if ($content -notmatch '--ps1') { throw "sp-auth.js should handle --ps1 flag" }
}

# ============================================================================
# 7. sp-auth-wrapper.ps1: protocol stripping
# ============================================================================
Write-Host "`n🔗 sp-auth-wrapper.ps1 validation" -ForegroundColor Cyan

Test "sp-auth-wrapper.ps1 has param block" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth-wrapper.ps1") -Raw
    if ($content -notmatch '(?m)^\s*param\s*\(') { throw "sp-auth-wrapper.ps1 missing param() block" }
}

Test "sp-auth-wrapper.ps1 calls sp-auth.js" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth-wrapper.ps1") -Raw
    if ($content -notmatch 'sp-auth\.js') { throw "sp-auth-wrapper.ps1 should call sp-auth.js" }
}

Test "sp-auth-wrapper.ps1 passes --ps1 flag" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth-wrapper.ps1") -Raw
    if ($content -notmatch '--ps1') { throw "sp-auth-wrapper.ps1 should pass --ps1 flag" }
}

# ============================================================================
# 8. sp-auth-wrapper.sh validation
# ============================================================================
Write-Host "`n🌐 sp-auth-wrapper.sh validation" -ForegroundColor Cyan

Test "sp-auth-wrapper.sh exists" {
    $path = Join-Path $scriptDir "sp-auth-wrapper.sh"
    if (-not (Test-Path $path)) { throw "sp-auth-wrapper.sh not found at $path" }
}

Test "sp-auth-wrapper.sh has shebang" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth-wrapper.sh") -First 1
    if ($content -notmatch '#!/bin/bash') { throw "sp-auth-wrapper.sh should have #!/bin/bash shebang" }
}

Test "sp-auth-wrapper.sh calls sp-auth.js" {
    $content = Get-Content (Join-Path $scriptDir "sp-auth-wrapper.sh") -Raw
    if ($content -notmatch 'sp-auth\.js') { throw "sp-auth-wrapper.sh should call sp-auth.js" }
}

# ============================================================================
# 9. sp-post.ps1: supports method override (3rd parameter)
# ============================================================================
Write-Host "`n🔀 sp-post.ps1 method override" -ForegroundColor Cyan

Test "sp-post.ps1 accepts MethodOverride parameter" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.ps1") -Raw
    if ($content -notmatch 'MethodOverride|Position\s*=\s*2') {
        throw "sp-post.ps1 should accept a 3rd positional parameter for method override"
    }
}

Test "sp-post.ps1 supports PATCH method" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.ps1") -Raw
    if ($content -notmatch "PATCH") { throw "sp-post.ps1 should reference PATCH method" }
}

Test "sp-post.ps1 supports DELETE method" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.ps1") -Raw
    if ($content -notmatch "DELETE") { throw "sp-post.ps1 should reference DELETE method" }
}

Test "sp-post.ps1 sets X-HTTP-Method header for override" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.ps1") -Raw
    if ($content -notmatch "X-HTTP-Method") { throw "sp-post.ps1 should set X-HTTP-Method header" }
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host "`n$("-" * 50)"
$color = if ($fail -eq 0) { "Green" } else { "Red" }
Write-Host "$pass/$total passed" -ForegroundColor $color
if ($fail -gt 0) { Write-Host "$fail failed" -ForegroundColor Red }
exit $fail
