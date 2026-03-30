#!/bin/bash
# ============================================================================
# test-scripts.sh — Offline validation of sharepoint-api-skill scripts
# ============================================================================
# Runs without network calls or external dependencies (beyond bash/node).
# Usage:  bash ./tests/test-scripts.sh
# Exit:   0 = all passed, non-zero = failure count
# ============================================================================

set +e  # don't exit on test failures

SCRIPT_DIR="$(cd "$(dirname "$0")/../.claude/skills/sharepoint-api/scripts" && pwd)"

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

# Helper: run a node script with env vars cleared, capture stderr + exit code
LAST_EXIT=0
LAST_STDERR=""
LAST_STDOUT=""
run_script() {
    local script="$1"; shift
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    (
        unset SP_TOKEN SP_COOKIES SP_SITE GRAPH_TOKEN
        node "$script" "$@"
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

for s in sp-get.js sp-post.js graph-get.js graph-post.js sp-auth.js; do
    test_case "$s exists" test -f "$SCRIPT_DIR/$s"
done

for s in sp-auth-wrapper.sh sp-auth-wrapper.ps1; do
    test_case "$s exists" test -f "$SCRIPT_DIR/$s"
done

# ============================================================================
# 2. HAS SHEBANG LINE
# ============================================================================
echo ""
echo "📝 Has node shebang line"

_test_node_shebang() {
    head -1 "$1" | tr -d '\r' | grep -q "node"
}
for s in sp-get.js sp-post.js graph-get.js graph-post.js sp-auth.js; do
    test_case "$s has node shebang" _test_node_shebang "$SCRIPT_DIR/$s"
done

_test_bash_shebang() {
    head -1 "$1" | tr -d '\r' | grep -q "^#!/bin/bash"
}
test_case "sp-auth-wrapper.sh has #!/bin/bash shebang" _test_bash_shebang "$SCRIPT_DIR/sp-auth-wrapper.sh"

# ============================================================================
# 3. ERROR ON MISSING ARGS
# ============================================================================
echo ""
echo "🚫 Error on missing arguments"

run_script "$SCRIPT_DIR/sp-get.js"
test_case "sp-get.js fails with no args" test "$LAST_EXIT" -ne 0

run_script "$SCRIPT_DIR/sp-post.js"
test_case "sp-post.js fails with no args" test "$LAST_EXIT" -ne 0

run_script "$SCRIPT_DIR/graph-get.js"
test_case "graph-get.js fails with no args" test "$LAST_EXIT" -ne 0

run_script "$SCRIPT_DIR/graph-post.js"
test_case "graph-post.js fails with no args" test "$LAST_EXIT" -ne 0

# ============================================================================
# 4. ERROR ON MISSING ENV VARS
# ============================================================================
echo ""
echo "🔑 Error on missing environment variables"

_test_sp_get_no_site() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_COOKIES; export SP_TOKEN=fake; node "$SCRIPT_DIR/sp-get.js" "/_api/web" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_SITE"
}
test_case "sp-get.js fails when SP_SITE is missing" _test_sp_get_no_site

_test_sp_get_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_TOKEN SP_COOKIES; export SP_SITE="https://test.sharepoint.com"; node "$SCRIPT_DIR/sp-get.js" "/_api/web" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_TOKEN"
}
test_case "sp-get.js fails when SP_TOKEN and SP_COOKIES are both missing" _test_sp_get_no_token

_test_sp_post_no_site() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_COOKIES; export SP_TOKEN=fake; node "$SCRIPT_DIR/sp-post.js" "/_api/web/lists" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_SITE"
}
test_case "sp-post.js fails when SP_SITE is missing" _test_sp_post_no_site

_test_sp_post_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset SP_TOKEN SP_COOKIES; export SP_SITE="https://test.sharepoint.com"; node "$SCRIPT_DIR/sp-post.js" "/_api/web/lists" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "SP_TOKEN"
}
test_case "sp-post.js fails when SP_TOKEN and SP_COOKIES are both missing" _test_sp_post_no_token

_test_graph_get_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; node "$SCRIPT_DIR/graph-get.js" "/v1.0/me" ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "GRAPH_TOKEN"
}
test_case "graph-get.js fails when GRAPH_TOKEN is missing" _test_graph_get_no_token

_test_graph_post_no_token() {
    local tmpout; tmpout=$(mktemp)
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; node "$SCRIPT_DIR/graph-post.js" "/v1.0/me" '{}' ) >"$tmpout" 2>"$tmperr"
    local rc=$?
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmpout" "$tmperr"
    test "$rc" -ne 0 && assert_contains "$LAST_STDERR" "GRAPH_TOKEN"
}
test_case "graph-post.js fails when GRAPH_TOKEN is missing" _test_graph_post_no_token

# ============================================================================
# 5. HELPFUL ERROR MESSAGES (reference sp-auth)
# ============================================================================
echo ""
echo "💡 Helpful error messages reference sp-auth"

_test_sp_get_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_TOKEN SP_COOKIES; node "$SCRIPT_DIR/sp-get.js" "/_api/web" ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "sp-get.js error mentions sp-auth" _test_sp_get_mentions_auth

_test_sp_post_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset SP_SITE SP_TOKEN SP_COOKIES; node "$SCRIPT_DIR/sp-post.js" "/_api/web" '{}' ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "sp-post.js error mentions sp-auth" _test_sp_post_mentions_auth

_test_graph_get_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; node "$SCRIPT_DIR/graph-get.js" "/v1.0/me" ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "graph-get.js error mentions sp-auth" _test_graph_get_mentions_auth

_test_graph_post_mentions_auth() {
    local tmperr; tmperr=$(mktemp)
    ( unset GRAPH_TOKEN; node "$SCRIPT_DIR/graph-post.js" "/v1.0/me" '{}' ) 2>"$tmperr" >/dev/null
    LAST_STDERR=$(cat "$tmperr"); rm -f "$tmperr"
    assert_contains "$LAST_STDERR" "sp-auth"
}
test_case "graph-post.js error mentions sp-auth" _test_graph_post_mentions_auth

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
# 7. sp-auth.js: protocol stripping
# ============================================================================
echo ""
echo "🔗 sp-auth.js protocol stripping"

test_case "sp-auth.js has protocol strip logic" assert_file_contains "$SCRIPT_DIR/sp-auth.js" "https?://"

test_case "sp-auth-wrapper.sh calls sp-auth.js" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.sh" "sp-auth\.js"

test_case "sp-auth-wrapper.ps1 calls sp-auth.js" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.ps1" "sp-auth\.js"

# ============================================================================
# 8. sp-auth-wrapper.sh validation
# ============================================================================
echo ""
echo "🌐 sp-auth-wrapper validation"

test_case "sp-auth-wrapper.sh has shebang" _test_bash_shebang "$SCRIPT_DIR/sp-auth-wrapper.sh"

test_case "sp-auth-wrapper.sh uses eval" \
    assert_file_contains "$SCRIPT_DIR/sp-auth-wrapper.sh" "eval"

# ============================================================================
# 9. sp-post.js: supports method override (3rd argument)
# ============================================================================
echo ""
echo "🔀 sp-post.js method override"

test_case "sp-post.js accepts 3rd argument (methodOverride)" \
    assert_file_contains "$SCRIPT_DIR/sp-post.js" 'methodOverride'

test_case "sp-post.js references PATCH" \
    assert_file_contains "$SCRIPT_DIR/sp-post.js" "PATCH"

test_case "sp-post.js references DELETE" \
    assert_file_contains "$SCRIPT_DIR/sp-post.js" "DELETE"

test_case "sp-post.js sets X-HTTP-Method header" \
    assert_file_contains "$SCRIPT_DIR/sp-post.js" "X-HTTP-Method"

test_case "graph-post.js accepts 3rd argument (method override)" \
    assert_file_contains "$SCRIPT_DIR/graph-post.js" 'argv\[4\]'

# ============================================================================
# 10. Zero npm dependencies
# ============================================================================
echo ""
echo "📦 Zero npm dependencies"

_test_no_require() {
    ! grep -q 'require\s*(' "$1"
}
for s in sp-get.js sp-post.js graph-get.js graph-post.js; do
    test_case "$s has no require() calls" _test_no_require "$SCRIPT_DIR/$s"
done

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
