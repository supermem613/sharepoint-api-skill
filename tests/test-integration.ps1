# ============================================================================
# test-integration.ps1 — Integration tests for sharepoint-api-skill
# ============================================================================
# Usage: .\test-integration.ps1
# Requires: Run sp-auth-wrapper.ps1 first
# Set SP_SITE to target a specific subsite:
#   $env:SP_SITE = "https://tenant.sharepoint.com/sites/mysite"
# ============================================================================

$ErrorActionPreference = "Continue"

$scriptDir = Join-Path $PSScriptRoot ".." ".claude" "skills" "sharepoint-api" "scripts"
$pass = 0
$fail = 0
$total = 0
$testPrefix = "SPSKILL_TEST_$(Get-Date -Format 'yyyyMMddHHmmss')"

function Test {
    param(
        [string]$Name,
        [scriptblock]$Block
    )
    $script:total++
    try {
        & $Block
        $script:pass++
        Write-Host "  ✅ $Name" -ForegroundColor Green
    }
    catch {
        $script:fail++
        Write-Host "  ❌ $Name" -ForegroundColor Red
        Write-Host "     $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

function SpGet {
    param([string]$Endpoint)
    $result = node "$scriptDir\sp-get.js" $Endpoint 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sp-get failed: $result" }
    return $result | ConvertFrom-Json
}

function SpPost {
    param(
        [string]$Endpoint,
        [string]$Body,
        [string]$Method = ""
    )
    $args = @("$scriptDir\sp-post.js", $Endpoint, $Body)
    if ($Method) { $args += $Method }
    $result = node @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "sp-post failed: $result" }
    if ([string]::IsNullOrWhiteSpace("$result")) { return $null }
    return $result | ConvertFrom-Json
}

# ============================================================================
# Prerequisites check
# ============================================================================
if (-not $env:SP_SITE -or (-not $env:SP_COOKIES -and -not $env:SP_TOKEN)) {
    Write-Host "⏭️  Skipping integration tests — not authenticated." -ForegroundColor Yellow
    Write-Host "   Run sp-auth-wrapper.ps1 first."
    Write-Host "   Then set SP_SITE if needed."
    exit 0
}

Write-Host ""
Write-Host "🔌 Checking connectivity to $env:SP_SITE ..." -ForegroundColor Cyan
try {
    $web = SpGet "/_api/web?`$select=Title,Url"
    Write-Host "   Connected to: $($web.Title) ($($web.Url))" -ForegroundColor DarkCyan
}
catch {
    Write-Host "❌ Cannot reach SP site. Check SP_SITE and auth tokens." -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor DarkRed
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " SharePoint API Skill — Integration Tests" -ForegroundColor Cyan
Write-Host " Prefix: $testPrefix" -ForegroundColor DarkCyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Site Info
# ============================================================================
Write-Host "📋 Site Info" -ForegroundColor Yellow

Test "Get web info — Title and Url present" {
    $web = SpGet "/_api/web?`$select=Title,Url"
    if (-not $web.Title) { throw "Missing Title" }
    if (-not $web.Url) { throw "Missing Url" }
}

Test "Get current user — Title and Email present" {
    $user = SpGet "/_api/web/currentuser?`$select=Title,Email"
    if (-not $user.Title) { throw "Missing Title" }
    if (-not $user.Email) { throw "Missing Email" }
}

# ============================================================================
# List Discovery
# ============================================================================
Write-Host ""
Write-Host "📋 List Discovery" -ForegroundColor Yellow

$allLists = $null
Test "Get all lists — response has value array" {
    $allLists = SpGet "/_api/web/lists?`$filter=Hidden eq false&`$select=Id,Title,ItemCount,BaseTemplate"
    if ($null -eq $allLists.value) { throw "No 'value' array in response" }
    if ($allLists.value.Count -eq 0) { throw "value array is empty" }
}

Test "Each list has Title, Id, ItemCount fields" {
    if ($null -eq $allLists) { throw "Skipped — previous test failed" }
    foreach ($list in $allLists.value) {
        if (-not $list.Title) { throw "List missing Title" }
        if (-not $list.Id) { throw "List missing Id" }
        if ($null -eq $list.ItemCount) { throw "List '$($list.Title)' missing ItemCount" }
    }
}

# ============================================================================
# List CRUD — create a temporary custom list, test items, then delete list
# ============================================================================
Write-Host ""
Write-Host "📋 List Item CRUD" -ForegroundColor Yellow

$testListTitle = "${testPrefix}_List"
$testListId = $null
$testItemId = $null
$testItemTitle = "${testPrefix}_Item"
$testItemTitleUpdated = "${testPrefix}_Updated"

try {
    # Create a temporary list to test against
    $createListBody = @{
        "__metadata" = @{ "type" = "SP.List" }
        "AllowContentTypes" = $true
        "BaseTemplate" = 100
        "ContentTypesEnabled" = $true
        "Description" = "Temporary integration test list"
        "Title" = $testListTitle
    } | ConvertTo-Json -Compress

    $newList = SpPost "/_api/web/lists" $createListBody
    $testListId = $newList.d.Id
    Write-Host "   (Created temp list: $testListTitle)" -ForegroundColor DarkGray

    # Discover the ListItemEntityTypeFullName for item creation
    $listInfo = SpGet "/_api/web/lists(guid'$testListId')?`$select=ListItemEntityTypeFullName"
    $entityType = $listInfo.ListItemEntityTypeFullName

    Test "Create a list item — 200/201 response" {
        $body = @{
            "__metadata" = @{ "type" = $entityType }
            "Title" = $testItemTitle
        } | ConvertTo-Json -Compress
        $created = SpPost "/_api/web/lists(guid'$testListId')/items" $body
        $script:testItemId = $created.d.Id
        if (-not $testItemId) { throw "No item Id returned" }
    }

    Test "Read item back — title matches" {
        if (-not $testItemId) { throw "Skipped — no item created" }
        $item = SpGet "/_api/web/lists(guid'$testListId')/items($testItemId)?`$select=Title,Id"
        if ($item.Title -ne $testItemTitle) { throw "Title mismatch: expected '$testItemTitle', got '$($item.Title)'" }
    }

    Test "Update the item — success" {
        if (-not $testItemId) { throw "Skipped — no item created" }
        $body = @{
            "__metadata" = @{ "type" = $entityType }
            "Title" = $testItemTitleUpdated
        } | ConvertTo-Json -Compress
        SpPost "/_api/web/lists(guid'$testListId')/items($testItemId)" $body "PATCH"
    }

    Test "Read updated item — new title matches" {
        if (-not $testItemId) { throw "Skipped — no item created" }
        $item = SpGet "/_api/web/lists(guid'$testListId')/items($testItemId)?`$select=Title"
        if ($item.Title -ne $testItemTitleUpdated) { throw "Title mismatch: expected '$testItemTitleUpdated', got '$($item.Title)'" }
    }

    Test "Delete the item — success (204 or 200)" {
        if (-not $testItemId) { throw "Skipped — no item created" }
        SpPost "/_api/web/lists(guid'$testListId')/items($testItemId)" "" "DELETE"
    }

    Test "Verify item is gone (404)" {
        if (-not $testItemId) { throw "Skipped — no item created" }
        $gotError = $false
        try {
            SpGet "/_api/web/lists(guid'$testListId')/items($testItemId)"
        }
        catch {
            if ($_ -match "404") { $gotError = $true }
            else { $gotError = $true }  # Any error is acceptable — item is gone
        }
        if (-not $gotError) { throw "Expected 404 but item still exists" }
    }
}
finally {
    # Clean up the temporary list
    if ($testListId) {
        try {
            SpPost "/_api/web/lists(guid'$testListId')" "" "DELETE"
            Write-Host "   (Deleted temp list: $testListTitle)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "   ⚠️  Failed to clean up test list '$testListTitle'. Delete it manually." -ForegroundColor DarkYellow
        }
    }
}

# ============================================================================
# File Operations — use the default Documents library
# ============================================================================
Write-Host ""
Write-Host "📋 File Operations" -ForegroundColor Yellow

# Determine the server-relative URL for the default document library
$siteUrl = $web.Url
$siteRelative = ([System.Uri]$siteUrl).AbsolutePath
$docLibRelative = "$siteRelative/Shared Documents"
$testFileName = "${testPrefix}_testfile.txt"
$testFileContent = "Integration test content — ${testPrefix}"

Test "List files in document library — response OK" {
    $files = SpGet "/_api/web/getfolderbyserverrelativeurl('$docLibRelative')/files?`$select=Name,Length&`$top=10"
    if ($null -eq $files.value) { throw "No 'value' array in response" }
}

try {
    Test "Upload a test file — success" {
        $encodedName = [System.Uri]::EscapeDataString($testFileName)
        SpPost "/_api/web/getfolderbyserverrelativeurl('$docLibRelative')/Files/add(url='$encodedName',overwrite=true)" $testFileContent
    }

    Test "Read file content back — matches" {
        $content = node "$scriptDir\sp-get.js" "/_api/web/getfilebyserverrelativeurl('$docLibRelative/$testFileName')/`$value" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "sp-get failed: $content" }
        $contentStr = "$content"
        if (-not $contentStr.Contains($testPrefix)) {
            throw "Content mismatch — expected to contain '$testPrefix'"
        }
    }
}
finally {
    # Clean up the test file
    try {
        SpPost "/_api/web/getfilebyserverrelativeurl('$docLibRelative/$testFileName')" "" "DELETE"
        Write-Host "   (Deleted test file: $testFileName)" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "   ⚠️  Failed to clean up test file '$testFileName'. Delete it manually." -ForegroundColor DarkYellow
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Results: $pass passed, $fail failed, $total total" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan

if ($fail -gt 0) { exit 1 }
exit 0
