#!/bin/bash
set -uo pipefail
# ============================================================================
# test-integration.sh — Integration tests for sharepoint-api-skill
# ============================================================================
# Usage: ./test-integration.sh
# Requires: Run sp-auth-wrapper.sh first
# Set SP_SITE to target a specific subsite:
#   export SP_SITE="https://tenant.sharepoint.com/sites/mysite"
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/skills/sharepoint-api/scripts" && pwd)"
PASS=0
FAIL=0
TOTAL=0
TEST_PREFIX="SPSKILL_TEST_$(date +%Y%m%d%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
DARK_YELLOW='\033[0;33m'
NC='\033[0m'

# Run a named test. Pass the test name and a function name.
run_test() {
    local name="$1"
    local func="$2"
    TOTAL=$((TOTAL + 1))
    if "$func" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo -e "  ${GREEN}✅ ${name}${NC}"
    else
        FAIL=$((FAIL + 1))
        echo -e "  ${RED}❌ ${name}${NC}"
    fi
}

sp_get() {
    node "$SCRIPT_DIR/sp-get.js" "$1"
}

sp_post() {
    local args=("$SCRIPT_DIR/sp-post.js" "$1" "$2")
    if [[ -n "${3:-}" ]]; then args+=("$3"); fi
    node "${args[@]}"
}

json_val() {
    local json="$1" field="$2"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".$field"
    else
        echo "$json" | sed 's/.*"'"$field"'":"\([^"]*\)".*/\1/'
    fi
}

json_val_d() {
    local json="$1" field="$2"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".d.$field"
    else
        echo "$json" | sed 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/'
    fi
}

json_array_len() {
    local json="$1"
    if command -v jq &>/dev/null; then
        echo "$json" | jq '.value | length'
    else
        echo "$json" | grep -o '"Title"' | wc -l
    fi
}

# ============================================================================
# Prerequisites check
# ============================================================================
if [[ -z "${SP_SITE:-}" ]] || { [[ -z "${SP_COOKIES:-}" ]] && [[ -z "${SP_TOKEN:-}" ]]; }; then
    echo -e "${YELLOW}⏭️  Skipping integration tests — not authenticated.${NC}"
    echo "   Run sp-auth-wrapper.sh first."
    echo "   Then set SP_SITE if needed."
    exit 0
fi

echo ""
echo -e "${CYAN}🔌 Checking connectivity to ${SP_SITE} ...${NC}"
WEB_INFO=$(sp_get '/_api/web?$select=Title,Url' 2>&1) || {
    echo -e "${RED}❌ Cannot reach SP site. Check SP_SITE and auth tokens.${NC}"
    exit 1
}
WEB_TITLE=$(json_val "$WEB_INFO" "Title")
WEB_URL=$(json_val "$WEB_INFO" "Url")
echo -e "${GRAY}   Connected to: ${WEB_TITLE} (${WEB_URL})${NC}"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN} SharePoint API Skill — Integration Tests${NC}"
echo -e "${GRAY} Prefix: ${TEST_PREFIX}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# Derive site-relative path for file operations
SITE_RELATIVE=$(echo "$WEB_URL" | sed 's|https\?://[^/]*||')
DOC_LIB_RELATIVE="${SITE_RELATIVE}/Shared Documents"

# ============================================================================
# Site Info
# ============================================================================
echo -e "${YELLOW}📋 Site Info${NC}"

test_web_info() {
    local result title url
    result=$(sp_get '/_api/web?$select=Title,Url')
    title=$(json_val "$result" "Title")
    url=$(json_val "$result" "Url")
    [[ -n "$title" && "$title" != "null" && -n "$url" && "$url" != "null" ]]
}

test_current_user() {
    local result title email
    result=$(sp_get '/_api/web/currentuser?$select=Title,Email')
    title=$(json_val "$result" "Title")
    email=$(json_val "$result" "Email")
    [[ -n "$title" && "$title" != "null" && -n "$email" && "$email" != "null" ]]
}

run_test "Get web info — Title and Url present" test_web_info
run_test "Get current user — Title and Email present" test_current_user

# ============================================================================
# List Discovery
# ============================================================================
echo ""
echo -e "${YELLOW}📋 List Discovery${NC}"

ALL_LISTS=""

test_get_all_lists() {
    ALL_LISTS=$(sp_get '/_api/web/lists?$filter=Hidden%20eq%20false&$select=Id,Title,ItemCount,BaseTemplate')
    local count
    count=$(json_array_len "$ALL_LISTS")
    [[ "$count" -gt 0 ]]
}

test_list_fields() {
    [[ -n "$ALL_LISTS" ]] || return 1
    if command -v jq &>/dev/null; then
        local missing
        missing=$(echo "$ALL_LISTS" | jq '[.value[] | select(.Title == null or .Id == null or .ItemCount == null)] | length')
        [[ "$missing" -eq 0 ]]
    else
        echo "$ALL_LISTS" | grep -q '"Title"' && echo "$ALL_LISTS" | grep -q '"Id"' && echo "$ALL_LISTS" | grep -q '"ItemCount"'
    fi
}

run_test "Get all lists — response has value array with items" test_get_all_lists
run_test "Each list has Title, Id, ItemCount fields" test_list_fields

# ============================================================================
# List Item CRUD — create a temporary custom list, test items, then delete
# ============================================================================
echo ""
echo -e "${YELLOW}📋 List Item CRUD${NC}"

TEST_LIST_TITLE="${TEST_PREFIX}_List"
TEST_LIST_ID=""
TEST_ITEM_ID=""
TEST_ITEM_TITLE="${TEST_PREFIX}_Item"
TEST_ITEM_TITLE_UPDATED="${TEST_PREFIX}_Updated"
ENTITY_TYPE=""

cleanup_list() {
    if [[ -n "$TEST_LIST_ID" ]]; then
        if sp_post "/_api/web/lists(guid'${TEST_LIST_ID}')" "" "DELETE" &>/dev/null; then
            echo -e "   ${GRAY}(Deleted temp list: ${TEST_LIST_TITLE})${NC}"
        else
            echo -e "   ${DARK_YELLOW}⚠️  Failed to clean up test list '${TEST_LIST_TITLE}'. Delete it manually.${NC}"
        fi
    fi
}
trap cleanup_list EXIT

# Create a temporary list
CREATE_LIST_BODY="{\"__metadata\":{\"type\":\"SP.List\"},\"AllowContentTypes\":true,\"BaseTemplate\":100,\"ContentTypesEnabled\":true,\"Description\":\"Temporary integration test list\",\"Title\":\"${TEST_LIST_TITLE}\"}"
NEW_LIST=$(sp_post "/_api/web/lists" "$CREATE_LIST_BODY" 2>&1) || {
    echo -e "  ${RED}❌ Failed to create temp list — skipping CRUD tests${NC}"
    NEW_LIST=""
}

if [[ -n "$NEW_LIST" ]]; then
    TEST_LIST_ID=$(json_val_d "$NEW_LIST" "Id")
    echo -e "   ${GRAY}(Created temp list: ${TEST_LIST_TITLE})${NC}"

    # Get entity type for item creation
    LIST_META=$(sp_get "/_api/web/lists(guid'${TEST_LIST_ID}')?\$select=ListItemEntityTypeFullName" 2>/dev/null || true)
    ENTITY_TYPE=$(json_val "$LIST_META" "ListItemEntityTypeFullName")

    test_crud_create() {
        local body created
        body="{\"__metadata\":{\"type\":\"${ENTITY_TYPE}\"},\"Title\":\"${TEST_ITEM_TITLE}\"}"
        created=$(sp_post "/_api/web/lists(guid'${TEST_LIST_ID}')/items" "$body")
        TEST_ITEM_ID=$(json_val_d "$created" "Id")
        [[ -n "$TEST_ITEM_ID" && "$TEST_ITEM_ID" != "null" ]]
    }

    test_crud_read() {
        [[ -n "$TEST_ITEM_ID" ]] || return 1
        local item got_title
        item=$(sp_get "/_api/web/lists(guid'${TEST_LIST_ID}')/items(${TEST_ITEM_ID})?\$select=Title,Id")
        got_title=$(json_val "$item" "Title")
        [[ "$got_title" == "$TEST_ITEM_TITLE" ]]
    }

    test_crud_update() {
        [[ -n "$TEST_ITEM_ID" ]] || return 1
        local body
        body="{\"__metadata\":{\"type\":\"${ENTITY_TYPE}\"},\"Title\":\"${TEST_ITEM_TITLE_UPDATED}\"}"
        sp_post "/_api/web/lists(guid'${TEST_LIST_ID}')/items(${TEST_ITEM_ID})" "$body" "PATCH"
    }

    test_crud_read_updated() {
        [[ -n "$TEST_ITEM_ID" ]] || return 1
        local item got_title
        item=$(sp_get "/_api/web/lists(guid'${TEST_LIST_ID}')/items(${TEST_ITEM_ID})?\$select=Title")
        got_title=$(json_val "$item" "Title")
        [[ "$got_title" == "$TEST_ITEM_TITLE_UPDATED" ]]
    }

    test_crud_delete() {
        [[ -n "$TEST_ITEM_ID" ]] || return 1
        sp_post "/_api/web/lists(guid'${TEST_LIST_ID}')/items(${TEST_ITEM_ID})" "" "DELETE"
    }

    test_crud_gone() {
        [[ -n "$TEST_ITEM_ID" ]] || return 1
        ! sp_get "/_api/web/lists(guid'${TEST_LIST_ID}')/items(${TEST_ITEM_ID})" 2>/dev/null
    }

    run_test "Create a list item — 200/201 response" test_crud_create
    run_test "Read item back — title matches" test_crud_read
    run_test "Update the item — success" test_crud_update
    run_test "Read updated item — new title matches" test_crud_read_updated
    run_test "Delete the item — success (204 or 200)" test_crud_delete
    run_test "Verify item is gone (404)" test_crud_gone
fi

# ============================================================================
# File Operations — use the default Documents library
# ============================================================================
echo ""
echo -e "${YELLOW}📋 File Operations${NC}"

TEST_FILE_NAME="${TEST_PREFIX}_testfile.txt"
TEST_FILE_CONTENT="Integration test content — ${TEST_PREFIX}"
UPLOADED_FILE=false

test_file_list() {
    local files
    files=$(sp_get "/_api/web/getfolderbyserverrelativeurl('${DOC_LIB_RELATIVE}')/files?\$select=Name,Length&\$top=10")
    if command -v jq &>/dev/null; then
        echo "$files" | jq -e ".value" >/dev/null
    else
        echo "$files" | grep -q "value"
    fi
}

test_file_upload() {
    sp_post "/_api/web/getfolderbyserverrelativeurl('${DOC_LIB_RELATIVE}')/Files/add(url='${TEST_FILE_NAME}',overwrite=true)" "${TEST_FILE_CONTENT}"
    UPLOADED_FILE=true
}

test_file_read() {
    [[ "$UPLOADED_FILE" == "true" ]] || return 1
    local content
    content=$(sp_get "/_api/web/getfilebyserverrelativeurl('${DOC_LIB_RELATIVE}/${TEST_FILE_NAME}')/\$value")
    echo "$content" | grep -q "${TEST_PREFIX}"
}

run_test "List files in document library — response OK" test_file_list
run_test "Upload a test file — success" test_file_upload
run_test "Read file content back — matches" test_file_read

# Clean up test file
if sp_post "/_api/web/getfilebyserverrelativeurl('${DOC_LIB_RELATIVE}/${TEST_FILE_NAME}')" "" "DELETE" &>/dev/null; then
    echo -e "   ${GRAY}(Deleted test file: ${TEST_FILE_NAME})${NC}"
else
    echo -e "   ${DARK_YELLOW}⚠️  Failed to clean up test file '${TEST_FILE_NAME}'. Delete it manually.${NC}"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN} Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total${NC}"
else
    echo -e "${RED} Results: ${PASS} passed, ${FAIL} failed, ${TOTAL} total${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════${NC}"

[[ $FAIL -eq 0 ]]
