# SharePoint API Skill — Evals

42 evals against a SharePoint site. Each eval shows the exact command to run.

## How to Run

```
Run evals/run-evals.md against <site-url>
```

## Setup

Before evals, the agent must:

1. **Authenticate:** `source scripts/sp-auth-wrapper.sh <site-url>` (or `. .\scripts\sp-auth-wrapper.ps1 <site-url>` on PowerShell)

2. **Set SITE_PATH:** Extract the server-relative path from SP_SITE.
   Example: if `SP_SITE=https://contoso.sharepoint.com/sites/mysite`, then `SITE_PATH=/sites/mysite`

3. **Create a test list:**
   ```
   node scripts/sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"SHAREPOINT_API_SKILL_EVAL_List","BaseTemplate":100,"EnableVersioning":true,"AllowContentTypes":true,"ContentTypesEnabled":true}'
   ```
   Set **LIST_ID** from the response `Id`.

4. **Get the ListItemEntityTypeFullName:**
   ```
   node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')?$select=ListItemEntityTypeFullName"
   ```
   Set **ENTITY_TYPE** from the result.

5. **Create a test document library:**
   ```
   node scripts/sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"SHAREPOINT_API_SKILL_EVAL_DocLib","BaseTemplate":101}'
   ```
   Set **DOCLIB_ID** from the response `Id`.
   Then get the root folder URL:
   ```
   node scripts/sp-get.js "/_api/web/lists(guid'$DOCLIB_ID')/rootfolder?$select=ServerRelativeUrl"
   ```
   Set **DOCLIB_PATH** from the result `ServerRelativeUrl`.

These values (`SITE_PATH`, `LIST_ID`, `ENTITY_TYPE`, `DOCLIB_ID`, `DOCLIB_PATH`) are used throughout.

> ⚠️ Evals create/delete test data (prefixed `SHAREPOINT_API_SKILL_EVAL_`). Only run against test/dev sites.
> At the end, delete the test list and doc lib:
> - `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')" '' DELETE`
> - `node scripts/sp-post.js "/_api/web/lists(guid'$DOCLIB_ID')" '' DELETE`

## Scoring

For each eval: run the command, check the pass condition.
- ✅ **PASS** — command succeeded and pass condition met
- ⚠️ **PARTIAL** — env-dependent endpoint not available (noted on eval)
- ❌ **FAIL** — command failed or pass condition not met

After all evals, write the report to `evals/results/report.md`.

---

## Auth (1)

### 01 — Authenticate
**Run:** `node scripts/sp-get.js "/_api/web?$select=Title,Url"`
**Pass if:** HTTP 200 and output contains `"Title"` and `"Url"`

---

## Discovery (5)

### 02 — Discover lists
**Run:** `node scripts/sp-get.js "/_api/web/lists?$filter=Hidden eq false&$select=Id,Title,ItemCount"`
**Pass if:** Output contains `"value"` array with at least 1 list

### 03 — Get list schema
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/fields?$filter=Hidden eq false&$select=Title,InternalName,TypeAsString"`
**Pass if:** Output contains fields with `"TypeAsString"` (uses the test list created in setup)

### 04 — Get site info
**Run:** `node scripts/sp-get.js "/_api/web?$select=Title,Url,Description"`
**Pass if:** Output contains `"Title"` and `"Url"`

### 47 — Taxonomy ⚠️ env-dependent
**Run:** `node scripts/sp-get.js "/_api/v2.1/termstore"`
**Pass if:** HTTP 200. Score ⚠️ PARTIAL if 404 (endpoint not available on this environment).

### 48 — Content types
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/contenttypes?$select=Name,Id"`
**Pass if:** Output contains `"Name"` (uses the test list created in setup)

---

## List CRUD (15)

### 05 — Read items
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items?$select=Title,Id&$top=5"`
**Pass if:** Output contains `"value"` array with items

### 06 — Create item
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_ITEM"}'`
**Pass if:** HTTP 200/201 and response contains `"SHAREPOINT_API_SKILL_EVAL_ITEM"`. **Save the item ID as `SKILL_EVAL_ITEM_ID`.**

### 07 — Update item
**Depends on:** 06
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($SKILL_EVAL_ITEM_ID)" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_UPDATED"}' PATCH`
**Pass if:** HTTP 200/204 (empty response is OK for PATCH)

### 08 — Delete item
**Depends on:** 06
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($SKILL_EVAL_ITEM_ID)" '' DELETE`
**Pass if:** HTTP 200/204
**Cleanup:** This IS the cleanup for eval 06.

### 09 — Filter items
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items?$filter=Id gt 0&$select=Title,Id&$top=3"`
**Pass if:** Output contains items

### 20 — CAML query
**Setup:** Create a test item first: `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_CAML"}'` Save item ID as `CAML_ITEM_ID`.
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/GetItems" '{"query":{"__metadata":{"type":"SP.CamlQuery"},"ViewXml":"<View><Query><Where><Gt><FieldRef Name=\"Id\" /><Value Type=\"Integer\">0</Value></Gt></Where></Query><RowLimit>3</RowLimit></View>"}}'`
**Pass if:** HTTP 200 and response contains items
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($CAML_ITEM_ID)" '' DELETE`

### 21 — Add column
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields" '{"__metadata":{"type":"SP.Field"},"Title":"SHAREPOINT_API_SKILL_EVAL_COLUMN","FieldTypeKind":2}'`
**Pass if:** HTTP 200/201

### 22 — Delete column
**Depends on:** 21
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('SHAREPOINT_API_SKILL_EVAL_COLUMN')" '' DELETE`
**Pass if:** HTTP 200
**Cleanup:** This IS the cleanup for 21.

### 23 — Create view
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views" '{"__metadata":{"type":"SP.View"},"Title":"SHAREPOINT_API_SKILL_EVAL_VIEW","RowLimit":10,"PersonalView":false}'`
**Pass if:** HTTP 200/201 and response contains `"Id"`. **Save view ID as `SKILL_EVAL_VIEW_ID`.**

### 24 — Update view
**Depends on:** 23
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views(guid'$SKILL_EVAL_VIEW_ID')" '{"__metadata":{"type":"SP.View"},"Title":"SHAREPOINT_API_SKILL_EVAL_VIEW_UPDATED","RowLimit":5}' PATCH`
**Pass if:** HTTP 200/204

### 25 — Delete view
**Depends on:** 23
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views(guid'$SKILL_EVAL_VIEW_ID')" '' DELETE`
**Pass if:** HTTP 200/204
**Cleanup:** This IS the cleanup for 23.

### 26 — Create list
**Run:** `node scripts/sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"SHAREPOINT_API_SKILL_EVAL_LIST","BaseTemplate":100}'`
**Pass if:** HTTP 200/201 and response contains `"Id"`. **Save list ID as `SKILL_EVAL_LIST_ID`.**

### 27 — Delete list
**Depends on:** 26
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$SKILL_EVAL_LIST_ID')" '' DELETE`
**Pass if:** HTTP 200/204
**Cleanup:** This IS the cleanup for 26.

### 28 — Item versions
**Setup:** Create a test item: `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_VERSION"}'` Save item ID as `VERSION_ITEM_ID`.
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items($VERSION_ITEM_ID)/versions?$select=VersionLabel"`
**Pass if:** Output contains `"VersionLabel"` (at least 1 version)
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($VERSION_ITEM_ID)" '' DELETE`

### 29 — Apply column formatting
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('Title')" '{"__metadata":{"type":"SP.Field"},"CustomFormatter":"{\"elmType\":\"div\",\"txtContent\":\"@currentField\"}"}' PATCH`
**Pass if:** HTTP 200/204
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('Title')" '{"__metadata":{"type":"SP.Field"},"CustomFormatter":null}' PATCH`

---

## Files (7)

### 10 — List files
**Run:** `node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files?$select=Name,Length"`
**Pass if:** Output contains `"value"` array (may be empty — empty array is a PASS since it's a new doc lib)

### 11 — Read file
**Depends on:** 12 (upload the test file first)
**Run:** `node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-test-upload.txt')/$value"`
**Pass if:** HTTP 200 and output contains `"Hello from eval"`

### 12 — Upload file
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files/add(url='eval-test-upload.txt',overwrite=true)" "Hello from eval"`
**Pass if:** HTTP 200/201 and response contains `"eval-test-upload.txt"`

### 13 — Delete file
**Depends on:** 12
**Run:** `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-test-upload.txt')" '' DELETE`
**Pass if:** HTTP 200/204
**Cleanup:** This IS the cleanup for 12.

### 30 — Create folder
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/folders/add('SHAREPOINT_API_SKILL_EVAL_FOLDER')" ''`
**Pass if:** HTTP 200/201

### 31 — Rename folder
**Depends on:** 30
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER')" '{"__metadata":{"type":"SP.Folder"},"Name":"SHAREPOINT_API_SKILL_EVAL_FOLDER_RENAMED"}' PATCH`
**Pass if:** HTTP 200/204
**Cleanup:** Delete the renamed folder (also try original name in case rename failed):
- `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER_RENAMED')" '' DELETE`
- `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER')" '' DELETE` (ignore if 404)

### 32 — Move file
**Self-contained — does NOT depend on any other eval.**
**Setup:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files/add(url='eval-move-test.txt',overwrite=true)" "move me"`
**Run:** `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-move-test.txt')/moveto(newurl='$DOCLIB_PATH/eval-moved.txt',flags=1)" ''`
**Pass if:** HTTP 200
**Cleanup:** Delete both possible locations (ignore 404s):
- `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-moved.txt')" '' DELETE`
- `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-move-test.txt')" '' DELETE`

---

## Search (1)

### 15 — SP REST search
**Run:** `node scripts/sp-get.js "/_api/search/query?querytext='SHAREPOINT_API_SKILL_EVAL'&rowlimit=1"`
**Pass if:** HTTP 200 and output contains `"PrimaryQueryResult"` (search indexing may be slow — valid empty results are a PASS as long as the API structure is correct)

---

## Users & Permissions (3)

### 16 — Current user
**Run:** `node scripts/sp-get.js "/_api/web/currentuser?$select=Title,Email,Id,LoginName"`
**Pass if:** Output contains `"Title"` and `"Email"`

### 17 — List site users
**Run:** `node scripts/sp-get.js "/_api/web/siteusers?$select=Title,Email,Id&$top=5"`
**Pass if:** Output contains `"value"` array with at least 1 user

### 43 — Check permissions
**Run:** `node scripts/sp-get.js "/_api/web/roleassignments?$expand=Member,RoleDefinitionBindings&$top=5"`
**Pass if:** Output contains `"PrincipalId"` or `"RoleDefinitionBindings"`

---

## Pages (4)

### 36 — Create page
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages" '{"__metadata":{"type":"SP.Publishing.SitePage"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE","PageLayoutType":"Article"}'`
**Pass if:** HTTP 200/201 and response contains `"SHAREPOINT_API_SKILL_EVAL_PAGE"`. **Save page ID as `EVAL_PAGE_ID`.**
**Then publish:** `node scripts/sp-post.js "/_api/sitepages/pages($EVAL_PAGE_ID)/publish" ''`
**Publish pass if:** HTTP 200/204

### 35 — List pages (verify test page)
**Depends on:** 36
**Run:** `node scripts/sp-get.js "/_api/sitepages/pages?$select=Title,FileName,Id&$top=50"`
**Pass if:** Output contains `"value"` array and the test page (EVAL_PAGE_ID) appears in the list

### 37 — Edit page
**Depends on:** 36
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages($EVAL_PAGE_ID)" '{"__metadata":{"type":"SP.Publishing.SitePage"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE_UPDATED","Description":"Updated by eval"}' PATCH`
**Pass if:** HTTP 200/204

### 38 — Delete page
**Depends on:** 36
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages($EVAL_PAGE_ID)" '' DELETE`
**Pass if:** HTTP 200/204
**Cleanup:** This IS the cleanup for 36.

---

## Advanced (6)

### 18 — Recycle bin
**Run:** `node scripts/sp-get.js "/_api/web/recyclebin?$top=5&$select=Title,ItemType,DeletedDate"`
**Pass if:** HTTP 200 and output contains `"value"` (array may be empty — empty is a PASS)

### 19 — List views
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/views?$select=Title,Id,ServerRelativeUrl"`
**Pass if:** Output contains `"value"` array with at least 1 view

### 39 — Create rule ⚠️ env-dependent
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/SPListRules" '{"Condition":"<condition/>","ActionType":"Custom","ActionParams":"{\"action\":\"noop\"}","TriggerType":"OnNewItem","Title":"SHAREPOINT_API_SKILL_EVAL_RULE"}'`
**Pass if:** HTTP 200/201 and response contains `"Id"`. **Save rule ID as `EVAL_RULE_ID`.** Score ⚠️ PARTIAL if 404 (endpoint not available on this environment).

### 40 — Delete rule ⚠️ env-dependent
**Depends on:** 39
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/SPListRules($EVAL_RULE_ID)" '' DELETE`
**Pass if:** HTTP 200/204. Score ⚠️ PARTIAL if eval 39 was PARTIAL (endpoint unavailable).
**Cleanup:** This IS the cleanup for 39.

### 41 — Navigation
**Run:** `node scripts/sp-get.js "/_api/web/navigation/quicklaunch?$select=Title,Url,Id"`
**Pass if:** HTTP 200 and output contains `"value"` array

### 42 — Site features
**Run:** `node scripts/sp-get.js "/_api/web/features?$select=DefinitionId,DisplayName"`
**Pass if:** HTTP 200 and output contains `"value"` array

---

## Report

After completing all evals, write `evals/results/report.md`:

```
# Eval Report — [date]

**Site:** [site URL]
**Overall:** [passed]/42 ([percentage]%)

## Summary

| Category         | Passed | Total | Score |
|------------------|--------|-------|-------|
| Auth             |        | 1     |       |
| Discovery        |        | 5     |       |
| List CRUD        |        | 15    |       |
| Files            |        | 7     |       |
| Search           |        | 1     |       |
| Users            |        | 3     |       |
| Pages            |        | 4     |       |
| Advanced         |        | 6     |       |

## Results

| #  | Eval                  | Score | Notes |
|----|-----------------------|-------|-------|
| 01 | Authenticate          |       |       |
| 02 | Discover lists        |       |       |
| 03 | Get list schema       |       |       |
| 04 | Get site info         |       |       |
| 05 | Read items            |       |       |
| 06 | Create item           |       |       |
| 07 | Update item           |       |       |
| 08 | Delete item           |       |       |
| 09 | Filter items          |       |       |
| 10 | List files            |       |       |
| 11 | Read file             |       |       |
| 12 | Upload file           |       |       |
| 13 | Delete file           |       |       |
| 15 | SP REST search        |       |       |
| 16 | Current user          |       |       |
| 17 | List site users       |       |       |
| 18 | Recycle bin           |       |       |
| 19 | List views            |       |       |
| 20 | CAML query            |       |       |
| 21 | Add column            |       |       |
| 22 | Delete column         |       |       |
| 23 | Create view           |       |       |
| 24 | Update view           |       |       |
| 25 | Delete view           |       |       |
| 26 | Create list           |       |       |
| 27 | Delete list           |       |       |
| 28 | Item versions         |       |       |
| 29 | Column formatting     |       |       |
| 30 | Create folder         |       |       |
| 31 | Rename folder         |       |       |
| 32 | Move file             |       |       |
| 35 | List pages            |       |       |
| 36 | Create page           |       |       |
| 37 | Edit page             |       |       |
| 38 | Delete page           |       |       |
| 39 | Create rule           |       |       |
| 40 | Delete rule           |       |       |
| 41 | Navigation            |       |       |
| 42 | Site features         |       |       |
| 43 | Check permissions     |       |       |
| 47 | Taxonomy              |       |       |
| 48 | Content types         |       |       |

## Failures
[Details for any ❌ or ⚠️]
```
