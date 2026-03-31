# SharePoint API Skill — Evals

Evals against a SharePoint site. Each eval shows the exact command to run.

## How to Run

```
Run evals/run-evals.md against <site-url>
```

## Execution Model

The agent executes all evals using **Node.js only** — no bash, PowerShell, or shell-specific syntax.

**How to call scripts:** Use `execFileSync('node', [scriptPath, arg1, arg2, ...], { stdio: ['pipe','pipe','pipe'] })` from a Node.js context, or `node <script> <args>` from any shell. The scripts write results to stdout and errors to stderr. Exit code 0 = success. Use `stdio: pipe` to prevent child process stderr from leaking into the eval output.

**Temporary files:** If you create a temporary eval runner script, write it to a temp directory (e.g., `os.tmpdir()`), not inside the repo.

**How to check pass/fail:** A successful call writes JSON to stdout. A failed call writes `ERROR: ...` to stderr and exits non-zero. Check for `"ERROR"` in combined output, or check exit code.

**PATCH/DELETE return empty body** on success (HTTP 204). An empty stdout with no stderr error means PASS.

**Variable placeholders:** Commands below use `$LIST_ID`, `$ENTITY_TYPE`, etc. These are values captured during setup — substitute them with the actual values.

## Script Paths

Scripts live at `.claude/skills/sharepoint-api/scripts/` relative to the **repo root** (not the `evals/` directory):
- `sp-auth.js` — authenticate (writes `~/.sharepoint-api-skill/auth.json`)
- `sp-get.js` — SharePoint REST GET
- `sp-post.js` — SharePoint REST POST/PATCH/MERGE/DELETE (auto-fetches request digest)

## Setup

Before evals, the agent must:

1. **Authenticate:**
   ```
   node scripts/sp-auth.js <site-url>
   ```
   Auth is saved to `~/.sharepoint-api-skill/auth.json`. All subsequent script calls read it automatically.

2. **Clean up leftover artifacts from previous runs** (prevents "list already exists" errors):
   ```
   node scripts/sp-get.js "/_api/web/lists?$filter=Hidden eq false&$select=Id,Title"
   ```
   For each list/lib where Title starts with `SHAREPOINT_API_SKILL_EVAL_`, delete it:
   ```
   node scripts/sp-post.js "/_api/web/lists(guid'{id}')" '' DELETE
   ```

3. **Set SITE_PATH:** Extract the server-relative path from SP_SITE.
   Example: if `SP_SITE=https://contoso.sharepoint.com/sites/mysite`, then `SITE_PATH=/sites/mysite`

4. **Create a test list:**
   ```
   node scripts/sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"SHAREPOINT_API_SKILL_EVAL_List","BaseTemplate":100,"EnableVersioning":true,"AllowContentTypes":true,"ContentTypesEnabled":true}'
   ```
   Set **LIST_ID** from the response `Id` field. (Note: SP may return `Id`, `id`, or `ID` — check all casings.)

5. **Get the ListItemEntityTypeFullName:**
   ```
   node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')?$select=ListItemEntityTypeFullName"
   ```
   Set **ENTITY_TYPE** from the result (e.g., `SP.Data.SHAREPOINT_x005f_API_x005f_SKILL_x005f_EVAL_x005f_ListListItem`).

6. **Create a test document library:**
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

## Known Pitfalls (read before running)

These are issues discovered through multiple eval runs. Following these rules avoids false failures:

1. **Retry transient network errors.** `ETIMEDOUT`, `ECONNRESET`, `fetch failed` are transient — retry the command once before marking FAIL.

2. **Search querytext must be URL-encoded.** `querytext='...'` with literal single quotes causes HTTP 500. Use `%27` instead: `querytext=%27test%27`.

3. **Page edit returns 409 after publish.** `PATCH` to `/_api/sitepages/pages({id})` returns 409 "editing session ended". This is expected. **Fallback:** update via Site Pages list item with MERGE:
   ```
   node scripts/sp-post.js "/_api/web/lists/getbytitle('Site Pages')/items($PAGE_ID)" '{"__metadata":{"type":"SP.Data.SitePagesItem"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE_UPDATED"}' MERGE
   ```
   Score ✅ PASS if the MERGE fallback succeeds. The 409 error from the PATCH attempt is noise — ignore it.

4. **Cleanup errors are expected.** Move-file cleanup, folder cleanup, and other teardown steps may produce 404 errors when the resource was already deleted or moved. These are expected — ignore all errors from cleanup commands.

5. **Response `Id` field casing varies.** SP REST returns `Id` (PascalCase) for most objects, but some endpoints return `id` (lowercase) or `ID` (uppercase). When extracting IDs from responses, check all three casings: `obj.Id || obj.id || obj.ID`.

## Scoring

For each eval: run the command, check the pass condition.
- ✅ **PASS** — command succeeded and pass condition met
- ❌ **FAIL** — command failed or pass condition not met

After all evals, write the report to `evals/results/report.md`.

---

## Auth (1)

### 01 — Authenticate
**Run:** `node scripts/sp-get.js "/_api/web?$select=Title,Url"`
**Pass if:** stdout contains `"Title"` and `"Url"`

---

## Discovery (4)

### 02 — Discover lists
**Run:** `node scripts/sp-get.js "/_api/web/lists?$filter=Hidden eq false&$select=Id,Title,ItemCount"`
**Pass if:** stdout contains `"value"` array with at least 1 list

### 03 — Get list schema
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/fields?$filter=Hidden eq false&$select=Title,InternalName,TypeAsString"`
**Pass if:** stdout contains fields with `"TypeAsString"`

### 04 — Get site info
**Run:** `node scripts/sp-get.js "/_api/web?$select=Title,Url,Description"`
**Pass if:** stdout contains `"Title"` and `"Url"`

### 05 — Content types
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/contenttypes?$select=Name,Id"`
**Pass if:** stdout contains `"Name"`

---

## List CRUD (15)

### 06 — Read items
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items?$select=Title,Id&$top=5"`
**Pass if:** stdout contains `"value"` array

### 07 — Create item
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_ITEM"}'`
**Pass if:** stdout contains `"SHAREPOINT_API_SKILL_EVAL_ITEM"`. **Save the item ID as `ITEM_ID`.**

### 08 — Update item
**Depends on:** 07
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($ITEM_ID)" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_UPDATED"}' PATCH`
**Pass if:** no error (empty stdout is OK — PATCH returns 204)

### 09 — Delete item
**Depends on:** 07
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($ITEM_ID)" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for eval 07.

### 10 — Filter items
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items?$filter=Id gt 0&$select=Title,Id&$top=3"`
**Pass if:** stdout contains `"value"` array

### 11 — CAML query
**Setup:** Create a test item first: `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_CAML"}'` Save item ID as `CAML_ITEM_ID`.
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/GetItems" '{"query":{"__metadata":{"type":"SP.CamlQuery"},"ViewXml":"<View><RowLimit>3</RowLimit></View>"}}'`
**Pass if:** stdout contains items (JSON array with at least 1 item)
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($CAML_ITEM_ID)" '' DELETE`

### 12 — Add column
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields" '{"__metadata":{"type":"SP.Field"},"Title":"SHAREPOINT_API_SKILL_EVAL_COLUMN","FieldTypeKind":2}'`
**Pass if:** no error

### 13 — Delete column
**Depends on:** 12
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('SHAREPOINT_API_SKILL_EVAL_COLUMN')" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for 12.

### 14 — Create view
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views" '{"__metadata":{"type":"SP.View"},"Title":"SHAREPOINT_API_SKILL_EVAL_VIEW","RowLimit":10,"PersonalView":false}'`
**Pass if:** stdout contains `"Id"`. **Save view ID as `VIEW_ID`.**

### 15 — Update view
**Depends on:** 14
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views(guid'$VIEW_ID')" '{"__metadata":{"type":"SP.View"},"Title":"SHAREPOINT_API_SKILL_EVAL_VIEW_UPDATED","RowLimit":5}' PATCH`
**Pass if:** no error

### 16 — Delete view
**Depends on:** 14
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/views(guid'$VIEW_ID')" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for 14.

### 17 — Create list
**Run:** `node scripts/sp-post.js "/_api/web/lists" '{"__metadata":{"type":"SP.List"},"Title":"SHAREPOINT_API_SKILL_EVAL_LIST2","BaseTemplate":100}'`
**Pass if:** stdout contains `"Id"`. **Save list ID as `LIST2_ID`.**

### 18 — Delete list
**Depends on:** 17
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST2_ID')" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for 17.

### 19 — Item versions
**Setup:** Create a test item: `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items" '{"__metadata":{"type":"$ENTITY_TYPE"},"Title":"SHAREPOINT_API_SKILL_EVAL_VERSION"}'` Save item ID as `VERSION_ITEM_ID`.
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/items($VERSION_ITEM_ID)/versions?$select=VersionLabel"`
**Pass if:** stdout contains `"VersionLabel"`
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/items($VERSION_ITEM_ID)" '' DELETE`

### 20 — Apply column formatting
**Run:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('Title')" '{"__metadata":{"type":"SP.Field"},"CustomFormatter":"{\"elmType\":\"div\",\"txtContent\":\"@currentField\"}"}' PATCH`
**Pass if:** no error
**Cleanup:** `node scripts/sp-post.js "/_api/web/lists(guid'$LIST_ID')/fields/getbytitle('Title')" '{"__metadata":{"type":"SP.Field"},"CustomFormatter":null}' PATCH`

---

## Files (7)

### 21 — Upload file
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files/add(url='eval-test-upload.txt',overwrite=true)" "Hello from eval"`
**Pass if:** stdout contains `"eval-test-upload.txt"`

### 22 — List files
**Depends on:** 21 (must have a file to list)
**Run:** `node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files?$select=Name,Length"`
**Pass if:** stdout contains `"value"` array with at least 1 file

### 23 — Read file
**Depends on:** 21
**Run:** `node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-test-upload.txt')/$value"`
**Pass if:** stdout contains `"Hello from eval"`

### 24 — Delete file
**Depends on:** 21
**Run:** `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-test-upload.txt')" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for 21.

### 25 — Create folder
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/folders/add('SHAREPOINT_API_SKILL_EVAL_FOLDER')" ''`
**Pass if:** no error

### 26 — Rename folder
**Depends on:** 25
**Run:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER')" '{"__metadata":{"type":"SP.Folder"},"Name":"SHAREPOINT_API_SKILL_EVAL_FOLDER_RENAMED"}' PATCH`
**Pass if:** no error
**Cleanup:** Delete the renamed folder (also try original name in case rename failed). Ignore 404s:
- `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER_RENAMED')" '' DELETE`
- `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH/SHAREPOINT_API_SKILL_EVAL_FOLDER')" '' DELETE`

### 27 — Move file
**Self-contained — does NOT depend on any other eval.**
**Setup:** `node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('$DOCLIB_PATH')/Files/add(url='eval-move-test.txt',overwrite=true)" "move me"`
**Run:** `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-move-test.txt')/moveto(newurl='$DOCLIB_PATH/eval-moved.txt',flags=1)" ''`
**Pass if:** no error
**Cleanup:** Delete both possible locations. Ignore 404s (the source no longer exists after a successful move):
- `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-moved.txt')" '' DELETE`
- `node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('$DOCLIB_PATH/eval-move-test.txt')" '' DELETE`

---

## Search (1)

### 28 — SP REST search
**Run:** `node scripts/sp-get.js "/_api/search/query?querytext=%27test%27&rowlimit=1"`
**Pass if:** stdout contains `"PrimaryQueryResult"`
> ⚠️ The querytext value MUST be URL-encoded: use `%27` for single quotes, not literal `'`. Literal quotes cause HTTP 500.

---

## Users & Permissions (3)

### 29 — Current user
**Run:** `node scripts/sp-get.js "/_api/web/currentuser?$select=Title,Email,Id,LoginName"`
**Pass if:** stdout contains `"Title"` and `"Email"`

### 30 — List site users
**Run:** `node scripts/sp-get.js "/_api/web/siteusers?$select=Title,Email,Id&$top=5"`
**Pass if:** stdout contains `"value"` array with at least 1 user

### 31 — Check permissions
**Run:** `node scripts/sp-get.js "/_api/web/roleassignments?$expand=Member,RoleDefinitionBindings&$top=5"`
**Pass if:** stdout contains `"PrincipalId"` or `"RoleDefinitionBindings"`

---

## Pages (4)

### 32 — Create page
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages" '{"__metadata":{"type":"SP.Publishing.SitePage"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE","PageLayoutType":"Article"}'`
**Pass if:** stdout contains `"SHAREPOINT_API_SKILL_EVAL_PAGE"`. **Save page ID as `PAGE_ID`.**
**Then publish:** `node scripts/sp-post.js "/_api/sitepages/pages($PAGE_ID)/publish" ''`
**Publish pass if:** no error

### 33 — List pages
**Depends on:** 32
**Run:** `node scripts/sp-get.js "/_api/sitepages/pages?$select=Title,FileName,Id&$top=50"`
**Pass if:** stdout contains `"value"` array

### 34 — Edit page
**Depends on:** 32
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages($PAGE_ID)" '{"__metadata":{"type":"SP.Publishing.SitePage"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE_UPDATED","Description":"Updated by eval"}' PATCH`
**Pass if:** no error
> ⚠️ **Expected behavior:** PATCH almost always returns 409 "editing session ended" after publish. This is not a failure — it's the normal SP behavior. **When 409 occurs**, fall back to updating via the Site Pages list item with MERGE:
> ```
> node scripts/sp-post.js "/_api/web/lists/getbytitle('Site Pages')/items($PAGE_ID)" '{"__metadata":{"type":"SP.Data.SitePagesItem"},"Title":"SHAREPOINT_API_SKILL_EVAL_PAGE_UPDATED"}' MERGE
> ```
> Score ✅ PASS if the MERGE fallback succeeds. Ignore the 409 error from the PATCH attempt.

### 35 — Delete page
**Depends on:** 32
**Run:** `node scripts/sp-post.js "/_api/sitepages/pages($PAGE_ID)" '' DELETE`
**Pass if:** no error
**Cleanup:** This IS the cleanup for 32.

---

## Advanced (4)

### 36 — Recycle bin
**Run:** `node scripts/sp-get.js "/_api/web/recyclebin?$top=5&$select=Title,ItemType,DeletedDate"`
**Pass if:** stdout contains `"value"` (array may be empty — empty is a PASS)

### 37 — List views
**Run:** `node scripts/sp-get.js "/_api/web/lists(guid'$LIST_ID')/views?$select=Title,Id,ServerRelativeUrl"`
**Pass if:** stdout contains `"value"` array with at least 1 view

### 38 — Navigation
**Run:** `node scripts/sp-get.js "/_api/web/navigation/quicklaunch?$select=Title,Url,Id"`
**Pass if:** stdout contains `"value"` array

### 39 — Site features
**Run:** `node scripts/sp-get.js "/_api/web/features?$select=DefinitionId,DisplayName"`
**Pass if:** stdout contains `"value"` array

---

## Report

After completing all evals, write `evals/results/report.md`:

```
# Eval Report — [date]

**Site:** [site URL]
**Overall:** [passed]/39 ([percentage]%) — [failed] failed

## Summary

| Category         | Pass | Fail | Total |
|------------------|------|------|-------|
| Auth             |      |       | 1     |
| Discovery        |      |       | 4     |
| List CRUD        |      |       | 15    |
| Files            |      |       | 7     |
| Search           |      |       | 1     |
| Users            |      |       | 3     |
| Pages            |      |       | 4     |
| Advanced         |      |      | 4     |

## Results

| #  | Eval                  | Score | Notes |
|----|-----------------------|-------|-------|
| 01 | Authenticate          |       |       |
| 02 | Discover lists        |       |       |
| 03 | Get list schema       |       |       |
| 04 | Get site info         |       |       |
| 05 | Content types         |       |       |
| 06 | Read items            |       |       |
| 07 | Create item           |       |       |
| 08 | Update item           |       |       |
| 09 | Delete item           |       |       |
| 10 | Filter items          |       |       |
| 11 | CAML query            |       |       |
| 12 | Add column            |       |       |
| 13 | Delete column         |       |       |
| 14 | Create view           |       |       |
| 15 | Update view           |       |       |
| 16 | Delete view           |       |       |
| 17 | Create list           |       |       |
| 18 | Delete list           |       |       |
| 19 | Item versions         |       |       |
| 20 | Column formatting     |       |       |
| 21 | Upload file           |       |       |
| 22 | List files            |       |       |
| 23 | Read file             |       |       |
| 24 | Delete file           |       |       |
| 25 | Create folder         |       |       |
| 26 | Rename folder         |       |       |
| 27 | Move file             |       |       |
| 28 | SP REST search        |       |       |
| 29 | Current user          |       |       |
| 30 | List site users       |       |       |
| 31 | Check permissions     |       |       |
| 32 | Create page           |       |       |
| 33 | List pages            |       |       |
| 34 | Edit page             |       |       |
| 35 | Delete page           |       |       |
| 36 | Recycle bin           |       |       |
| 37 | List views            |       |       |
| 38 | Navigation            |       |       |
| 39 | Site features         |       |       |

## Failures
[Details for any ❌]
```
