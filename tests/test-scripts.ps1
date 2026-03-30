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

# Helper: run a Node.js script in a child process with specific env vars.
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

    $cmd = "${envBlock}node '$ScriptPath' $argStr; exit `$LASTEXITCODE"

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

$nodeScripts = @("sp-get.js", "sp-post.js", "graph-get.js", "graph-post.js", "sp-auth.js")
foreach ($s in $nodeScripts) {
    Test "$s exists" {
        $path = Join-Path $scriptDir $s
        if (-not (Test-Path $path)) { throw "$s not found at $path" }
    }
}

$wrapperScripts = @("sp-auth-wrapper.ps1", "sp-auth-wrapper.sh")
foreach ($s in $wrapperScripts) {
    Test "$s exists" {
        $path = Join-Path $scriptDir $s
        if (-not (Test-Path $path)) { throw "$s not found at $path" }
    }
}

# ============================================================================
# 2. SHEBANG LINE tests
# ============================================================================
Write-Host "`n📝 Has shebang line" -ForegroundColor Cyan

foreach ($s in $nodeScripts) {
    Test "$s has node shebang" {
        $content = Get-Content (Join-Path $scriptDir $s) -First 1
        if ($content -notmatch 'node') { throw "$s should have node shebang" }
    }
}

# ============================================================================
# 3. ERROR ON MISSING ARGS tests
# ============================================================================
Write-Host "`n🚫 Error on missing arguments" -ForegroundColor Cyan

Test "sp-get.js fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.js") -EnvVars @{ SP_TOKEN = $null; SP_COOKIES = $null; SP_SITE = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

Test "sp-post.js fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.js") -EnvVars @{ SP_TOKEN = $null; SP_COOKIES = $null; SP_SITE = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

Test "graph-get.js fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.js") -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit code, got 0" }
}

Test "graph-post.js fails with no args" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.js") -EnvVars @{ GRAPH_TOKEN = $null }
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
Test "sp-get.js fails when SP_SITE is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.js") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = "fake"; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_SITE") { throw "Error should mention SP_SITE, got: $($r.Stderr)" }
}

Test "sp-get.js fails when SP_TOKEN and SP_COOKIES are both missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.js") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = "https://test.sharepoint.com"; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_TOKEN|SP_COOKIES") { throw "Error should mention SP_TOKEN/SP_COOKIES, got: $($r.Stderr)" }
}

# sp-post: needs SP_SITE + (SP_TOKEN or SP_COOKIES)
Test "sp-post.js fails when SP_SITE is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.js") -Arguments @("/_api/web/lists", '{}') `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = "fake"; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_SITE") { throw "Error should mention SP_SITE" }
}

Test "sp-post.js fails when SP_TOKEN and SP_COOKIES are both missing" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.js") -Arguments @("/_api/web/lists", '{}') `
        -EnvVars @{ SP_SITE = "https://test.sharepoint.com"; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "SP_TOKEN|SP_COOKIES") { throw "Error should mention SP_TOKEN/SP_COOKIES" }
}

# graph-get: needs GRAPH_TOKEN
Test "graph-get.js fails when GRAPH_TOKEN is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.js") -Arguments @("/v1.0/me") `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "GRAPH_TOKEN") { throw "Error should mention GRAPH_TOKEN" }
}

# graph-post: needs GRAPH_TOKEN
Test "graph-post.js fails when GRAPH_TOKEN is missing" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.js") -Arguments @("/v1.0/me", '{}') `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.ExitCode -eq 0) { throw "Expected non-zero exit" }
    if ($r.Stderr -notmatch "GRAPH_TOKEN") { throw "Error should mention GRAPH_TOKEN" }
}

# ============================================================================
# 5. HELPFUL ERROR MESSAGES (mention sp-auth)
# ============================================================================
Write-Host "`n💡 Helpful error messages reference sp-auth" -ForegroundColor Cyan

Test "sp-get.js error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-get.js") -Arguments @("/_api/web") `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth, got: $($r.Stderr)" }
}

Test "sp-post.js error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "sp-post.js") -Arguments @("/_api/web", '{}') `
        -EnvVars @{ SP_SITE = $null; SP_TOKEN = $null; SP_COOKIES = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth" }
}

Test "graph-get.js error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-get.js") -Arguments @("/v1.0/me") `
        -EnvVars @{ GRAPH_TOKEN = $null }
    if ($r.Stderr -notmatch "sp-auth") { throw "Error should reference sp-auth" }
}

Test "graph-post.js error mentions sp-auth" {
    $r = Invoke-Script (Join-Path $scriptDir "graph-post.js") -Arguments @("/v1.0/me", '{}') `
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
# 9. sp-post.js: supports method override (3rd argument)
# ============================================================================
Write-Host "`n🔀 sp-post.js method override" -ForegroundColor Cyan

Test "sp-post.js accepts 3rd argument for method override" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.js") -Raw
    if ($content -notmatch 'methodOverride|argv\[4\]') {
        throw "sp-post.js should accept a 3rd positional argument for method override"
    }
}

Test "sp-post.js supports PATCH method" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.js") -Raw
    if ($content -notmatch "PATCH") { throw "sp-post.js should reference PATCH method" }
}

Test "sp-post.js supports DELETE method" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.js") -Raw
    if ($content -notmatch "DELETE") { throw "sp-post.js should reference DELETE method" }
}

Test "sp-post.js sets X-HTTP-Method header for override" {
    $content = Get-Content (Join-Path $scriptDir "sp-post.js") -Raw
    if ($content -notmatch "X-HTTP-Method") { throw "sp-post.js should set X-HTTP-Method header" }
}

# ============================================================================
# 10. Node.js scripts use only built-in APIs (no require of npm packages)
# ============================================================================
Write-Host "`n📦 Zero npm dependencies" -ForegroundColor Cyan

foreach ($s in @("sp-get.js", "sp-post.js", "graph-get.js", "graph-post.js")) {
    Test "$s has no require() calls (uses only built-ins)" {
        $content = Get-Content (Join-Path $scriptDir $s) -Raw
        if ($content -match "require\s*\(") { throw "$s should not use require() — use Node.js built-in fetch" }
    }
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host "`n$("-" * 50)"
$color = if ($fail -eq 0) { "Green" } else { "Red" }
Write-Host "$pass/$total passed" -ForegroundColor $color
if ($fail -gt 0) { Write-Host "$fail failed" -ForegroundColor Red }
exit $fail
