#!/bin/bash
# ============================================================================
# test-scripts.sh — Offline validation of sharepoint-api-skill scripts
# ============================================================================
# Runs without network calls or external dependencies (beyond bash/curl).
# Usage:  bash ./tests/test-scripts.sh
# Exit:   0 = all passed, non-zero = failure count
# ============================================================================

set +e  # don't exit on test failures

SCRIPT_DIR="$(cd "$(dirname "$0")/../.claude/skills/sharepoint-api/scripts" && pwd)"

# On Windows, git may check out .sh files with CRLF.
# Create temp copies with LF line endings for reliable testing.
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
for f in "$SCRIPT_DIR"/*.sh; do
    tr -d '\r' < "$f" > "$WORK_DIR/$(basename "$f")"
    chmod +x "$WORK_DIR/$(basename "$f")"
done
# Keep SCRIPT_DIR for file-existence and .ps1 checks; use WORK_DIR for execution
EXEC_DIR="$WORK_DIR"

pass=0; fail=0; total=0

test_case() {
    local name="$1"
    shift
    total=$((total + 1))
    if "$@" 2>/dev/null; then
        pass=$((pass + 1))
        echo "  ✅ $name"
    else
        fail=$((fail + 1))
        echo "  ❌ $name"
    fi
}

# Helper: assert a string contains a substring
assert_contains() { echo "$1" | grep -qi "$2"; }

# Helper: assert file contains pattern
assert_file_contains() { grep -qE "$2" "$1"; }

# Helper: run a bash script with specific env vars cleared, capture stderr + exit code
# Usage: run_script "path" [args...] ; then check $LAST_EXIT, $LAST_STDERR
LAST_EXIT=0
LAST_STDERR=""
LAST_STDOUT=""
run_script() {
    local script="$1"; shift
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    # Run in a subshell with clean auth env vars
    (
        unset SP_TOKEN SP_COOKIES SP_SITE GRAPH_TOKEN
        bash "$script" "$@"
    ) >"$tmpout" 2>"$tmperr"
    LAST_EXIT=$?
    LAST_STDOUT=$(cat "$tmpout")
    LAST_STDERR=$(cat "$tmperr")
    rm -f "$tmpout" "$tmperr"
}

# Helper: run a bash script with specific env vars set
run_script_env() {
    local script="$1"; shift
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    (
        unset SP_TOKEN SP_COOKIES SP_SITE GRAPH_TOKEN
        # Source env vars passed as KEY=VALUE before remaining args
        while [[ "$1" == *=* ]]; do
            export "$1"
            shift
        done
        bash "$script" "$@"
    ) >"$tmpout" 2>"$tmperr"
    LAST_EXIT=$?
    LAST_STDOUT=$(cat "$tmpout")
    LAST_STDERR=$(cat "$tmperr")
    rm -f "$tmpout" "$tmperr"
}

# ============================================================================
# 1. FILE EXISTS
# ============================================================================
echo ""
echo "📁 File existence"

for s in sp-get.sh sp-post.sh graph-get.sh graph-post.sh sp-auth-wrapper.sh; do
    test_case "$s exists" test -f "$SCRIPT_DIR/$s"
done

# ============================================================================
# 2. HAS SHEBANG LINE
# ============================================================================
echo ""
echo "📝 Has shebang line"

_test_shebang() {
    head -1 "$1" | tr -d '\r' | grep -q "^#!/bin/bash"
}
for s in sp-get.sh sp-post.sh graph-get.sh graph-post.sh sp-auth-wrapper.sh; do
    test_case "$s has #!/bin/bash shebang" _test_shebang "$SCRIPT_DIR/$s"
done

# Also verify PS1 files exist and have param blocks
echo ""
echo "📝 PS1 scripts have param blocks"

for s in sp-get.ps1 sp-post.ps1 graph-get.ps1 graph-post.ps1 sp-auth-wrapper.ps1; do
    test_case "$s has param() block" grep -qE '^\s*param\s*\(' "$SCRIPT_DIR/$s"
done

# ============================================================================
# 3. ERROR ON MISSING ARGS
# ============================================================================
echo ""
echo "🚫 Error on missing arguments"

# sp-get.sh — requires endpoint
run_script "$EXEC_DIR/sp-get.sh"
test_case "sp-get.sh fails with no args" test "$LAST_EXIT" -ne 0

# sp-post.sh — requires endpoint + body
run_script "$EXEC_DIR/sp-post.sh"
test_case "sp-post.sh fails with no args" test "$LAST_EXIT" -ne 0

# graph-get.sh — requires endpoint
run_script "$EXEC_DIR/graph-get.sh"
test_case "graph-get.sh fails with no args" test "$LAST_EXIT" -ne 0

# graph-post.sh — requires endpoint + body
run_script "$EXEC_DIR/graph-post.sh"
test_case "graph-post.sh fails with no args" test "$LAST_EXIT" -ne 0

# sp-auth-wrapper.sh — requires tenant host (will fail without node/playwright but should source cleanly)
test_case "sp-auth-wrapper.sh exists" test -f "$SCRIPT_DIR/sp-auth-wrapper.sh"

# ============================================================================
# 4. ERROR ON MISSING ENV VARS
# ============================================================================
echo ""
echo "🔑 Error on missing environment variables"

# sp-get: missing SP_SITE
_test_sp_get_no_site() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_COOKIES; export SP_TOKEN=fake; bash "$EXEC_DIR/sp-get.sh" "/_api/web" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_SITE"
}
test_case "sp-get.sh fails when SP_SITE is missing" _test_sp_get_no_site

_test_sp_get_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_TOKEN SP_COOKIES; export SP_SITE="https://test.sharepoint.com"; bash "$EXEC_DIR/sp-get.sh" "/_api/web" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_TOKEN"
}
test_case "sp-get.sh fails when SP_TOKEN and SP_COOKIES are both missing" _test_sp_get_no_token

# sp-post: missing SP_SITE
_test_sp_post_no_site() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_COOKIES; export SP_TOKEN=fake; bash "$EXEC_DIR/sp-post.sh" "/_api/web/lists" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_SITE"
}
test_case "sp-post.sh fails when SP_SITE is missing" _test_sp_post_no_site

_test_sp_post_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_TOKEN SP_COOKIES; export SP_SITE="https://test.sharepoint.com"; bash "$EXEC_DIR/sp-post.sh" "/_api/web/lists" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_TOKEN"
}
test_case "sp-post.sh fails when SP_TOKEN and SP_COOKIES are both missing" _test_sp_post_no_token

# graph-get: missing GRAPH_TOKEN
_test_graph_get_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; bash "$EXEC_DIR/graph-get.sh" "/v1.0/me" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "GRAPH_TOKEN"
}
test_case "graph-get.sh fails when GRAPH_TOKEN is missing" _test_graph_get_no_token

# graph-post: missing GRAPH_TOKEN
_test_graph_post_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; bash "$EXEC_DIR/graph-post.sh" "/v1.0/me" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "GRAPH_TOKEN"
}
test_case "graph-post.sh fails when GRAPH_TOKEN is missing" _test_graph_post_no_token

# ============================================================================
# 5. HELPFUL ERROR MESSAGES (reference sp-auth)
# ============================================================================
echo ""
echo "💡 Helpful error messages reference sp-auth"

_test_sp_get_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_TOKEN SP_COOKIES; bash "$EXEC_DIR/sp-get.sh" "/_api/web" ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "sp-get.sh error mentions sp-auth" _test_sp_get_mentions_auth

_test_sp_post_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_TOKEN SP_COOKIES; bash "$EXEC_DIR/sp-post.sh" "/_api/web" '{}' ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "sp-post.sh error mentions sp-auth" _test_sp_post_mentions_auth

_test_graph_get_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; bash "$EXEC_DIR/graph-get.sh" "/v1.0/me" ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "graph-get.sh error mentions sp-auth" _test_graph_get_mentions_auth

_test_graph_post_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; bash "$EXEC_DIR/graph-post.sh" "/v1.0/me" '{}' ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "graph-post.sh error mentions sp-auth" _test_graph_post_mentions_auth

# ============================================================================
# 6. sp-auth.js: exists and uses playwright
# ============================================================================
echo ""
echo "🔧 sp-auth.js validation"

test_case "sp-auth.js exists" test -f "$SCRIPT_DIR/sp-auth.js"

test_case "sp-auth.js uses playwright" \
    assert_file_contains "$SCRIPT_DIR/sp-auth.js" "playwright"

test_case "sp-auth.js handles --login flag" \
    assert_file_contains "$SCRIPT_DIR/sp-auth.js" "\-\-login"

test_case "sp-auth.js handles --logout flag" \
    assert_file_contains "$SCRIPT_DIR/sp-auth.js" "\-\-logout"

test_case "sp-auth.js handles --ps1 flag" \
    assert_file_contains "$SCRIPT_DIR/sp-auth.js" "\-\-ps1"

# ============================================================================
# 7. sp-auth.js: protocol stripping in parseTenantHost
# ============================================================================
echo ""
echo "🔗 sp-auth.js protocol stripping"

test_case "sp-auth.js has protocol strip logic" assert_file_contains "$SCRIPT_DIR/sp-auth.js" "https?://"

test_case "sp-auth-wrapper.sh calls sp-auth.js" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.sh" "sp-auth\.js"

test_case "sp-auth-wrapper.ps1 calls sp-auth.js" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.ps1" "sp-auth\.js"

# ============================================================================
# 8. sp-auth-wrapper.sh: calls sp-auth.js
# ============================================================================
echo ""
echo "🌐 sp-auth-wrapper validation"

test_case "sp-auth-wrapper.sh has shebang" _test_shebang "$SCRIPT_DIR/sp-auth-wrapper.sh"

test_case "sp-auth-wrapper.sh uses eval" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.sh" "eval"

# ============================================================================
# 9. sp-post.sh: supports method override (3rd parameter)
# ============================================================================
echo ""
echo "🔀 sp-post.sh method override"

test_case "sp-post.sh accepts 3rd positional arg (METHOD_OVERRIDE)" \
    assert_file_contains "$SCRIPT_DIR/sp-post.sh" 'METHOD_OVERRIDE|\$\{3:-\}'

test_case "sp-post.sh references PATCH" \
    assert_file_contains "$SCRIPT_DIR/sp-post.sh" "PATCH"

test_case "sp-post.sh references DELETE" \
    assert_file_contains "$SCRIPT_DIR/sp-post.sh" "DELETE"

test_case "sp-post.sh sets X-HTTP-Method header" \
    assert_file_contains "$SCRIPT_DIR/sp-post.sh" "X-HTTP-Method"

# graph-post.sh also supports method override
test_case "graph-post.sh accepts 3rd positional arg (METHOD)" \
    assert_file_contains "$SCRIPT_DIR/graph-post.sh" 'METHOD|\$\{3:-'

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "--------------------------------------------------"
if [[ $fail -eq 0 ]]; then
    echo -e "\033[32m${pass}/${total} passed\033[0m"
else
    echo -e "\033[31m${pass}/${total} passed\033[0m"
    echo -e "\033[31m${fail} failed\033[0m"
fi
exit "$fail"
