# SharePoint API Skill — Evals

Run all 48 evals against a SharePoint site and produce a scored report.

## How to Run

Tell your agent:
```
Authenticate to <your-site-url>, then read evals/run-evals.md and run all evals.
```

Example:
```
Authenticate to contoso.sharepoint.com/sites/testsite, then read evals/run-evals.md and run all evals.
```

## Prerequisites

1. **Install dependencies** (one-time): `npm install`
2. The agent will authenticate as the first eval (01). If already authenticated, it skips ahead.

> ⚠️ Evals create/delete test data (prefixed EVAL_TEST_). Only run against test/dev sites.

## Instructions

Execute each eval below in order. For each:
1. Do the task
2. Check yourself against the criteria
3. Score: ✅ PASS | ⚠️ PARTIAL | ❌ FAIL

After all evals, write the report to `evals/results/report.md`.

---

## Auth

### 01 — Authenticate
**Task:** Authenticate to the site and verify by fetching the site title.
**Checks:** Ran sp-auth-wrapper · SP_COOKIES/SP_SITE set · GET /_api/web returned Title

---

## Discovery

### 02 — Discover lists
**Task:** List all non-hidden lists with names and item counts.
**Checks:** Used sp-get.js · Called /_api/web/lists with $filter=Hidden eq false · Output shows list names and counts

### 03 — Get list schema
**Task:** Get all columns for a list. Show Title, InternalName, TypeAsString.
**Checks:** Used sp-get.js · Called /fields endpoint · Output shows column details

### 04 — Get site info
**Task:** Get site title, URL, and description.
**Checks:** Used sp-get.js · Called /_api/web · Output shows Title and Url

### 46 — Resolve site ID
**Task:** Get the Microsoft Graph site ID from the SharePoint URL.
**Checks:** Used graph-get.js · Called /v1.0/sites/{hostname}:{path} · Got site ID

### 47 — Taxonomy
**Task:** Get the term store or term sets.
**Checks:** Used graph-get.js with /v1.0/sites/{siteId}/termStore OR sp-get.js with /_api/v2.1/termstore (requires SP_TOKEN) · Got response

### 48 — Content types
**Task:** List content types on a list.
**Checks:** Used sp-get.js · Called /contenttypes · Output shows content type names

---

## List CRUD

### 05 — Read items
**Task:** Get first 5 items from a list with Id and Title.
**Checks:** Used sp-get.js · Called /items with $top=5 · Shows items with Id and Title

### 06 — Create item
**Task:** Create item with Title "EVAL_TEST_ITEM". Note the list and item ID.
**Checks:** Used sp-post.js · POSTed to /items · Got success · Response has item ID

### 07 — Update item
**Task:** Update EVAL_TEST_ITEM to Title "EVAL_TEST_UPDATED".
**Checks:** Used sp-post.js with PATCH · Called /items({id}) · Success

### 08 — Delete item
**Task:** Delete the test item.
**Checks:** Used sp-post.js with DELETE · Called /items({id}) · Success

### 09 — Filter items
**Task:** Filter items using $filter or CAML query.
**Checks:** Used $filter or GetItems with CAML · Got filtered results

### 20 — CAML query
**Task:** Write and execute a CAML query with date/text filter.
**Checks:** Valid CAML XML with `<View><Query><Where>` · POSTed to GetItems · Got results

### 21 — Add column
**Task:** Add a text column named "EVAL_TEST_COLUMN" to a list.
**Checks:** Used sp-post.js · POSTed to /fields · Column appears in schema

### 22 — Delete column
**Task:** Delete the EVAL_TEST_COLUMN created in 21.
**Checks:** Used sp-post.js with DELETE · Called /fields/getbytitle(...) · Success

### 23 — Create view
**Task:** Create a view named "EVAL_TEST_VIEW" with specific fields.
**Checks:** Used sp-post.js · POSTed to /views · View appears in view list

### 24 — Update view
**Task:** Update EVAL_TEST_VIEW (change title or query).
**Checks:** Used sp-post.js with PATCH · Called /views({id}) · Success

### 25 — Delete view
**Task:** Delete EVAL_TEST_VIEW.
**Checks:** Used sp-post.js with DELETE · Called /views({id}) · Success

### 26 — Create list
**Task:** Create a list named "EVAL_TEST_LIST".
**Checks:** Used sp-post.js · POSTed to /_api/web/lists · List appears in list inventory

### 27 — Delete list
**Task:** Delete EVAL_TEST_LIST.
**Checks:** Used sp-post.js with DELETE · Success

### 28 — Item versions
**Task:** Get version history for a list item.
**Checks:** Used sp-get.js · Called /items({id})/versions · Shows versions

### 29 — Apply column formatting
**Task:** Apply JSON formatting to a column.
**Checks:** Used sp-post.js with PATCH · Set CustomFormatter on a field · Success

---

## Files

### 10 — List files
**Task:** List files in the default document library with name and size.
**Checks:** Used sp-get.js or graph-get.js · Called Files or drives/children · Shows filenames

### 11 — Read file
**Task:** Read content of a text/markdown file.
**Checks:** Used sp-get.js with /$value or graph-get.js with /content · Shows text content

### 12 — Upload file
**Task:** Upload "eval-test-upload.txt" with content "Hello from eval".
**Checks:** Used sp-post.js Files/add or graph PUT · File created

### 13 — Delete file
**Task:** Delete eval-test-upload.txt.
**Checks:** Used DELETE · File removed

### 30 — Create folder
**Task:** Create folder "EVAL_TEST_FOLDER" in document library.
**Checks:** Used sp-post.js · POSTed to /folders or Files/add · Folder exists

### 31 — Rename file
**Task:** Rename a file or folder.
**Checks:** Used sp-post.js with PATCH or graph PATCH · Name changed

### 32 — Move/copy file
**Task:** Copy or move a file to another location.
**Checks:** Used moveto/copyto endpoint or Graph copy · File exists in new location

### 33 — Share file
**Task:** Create a sharing link for a file.
**Checks:** Used graph-post.js · Called /createLink · Got sharing URL

### 34 — File versions
**Task:** Get version history for a file.
**Checks:** Used graph-get.js · Called /versions · Shows version list

---

## Search

### 14 — Graph search
**Task:** Search for files using Graph Search API.
**Checks:** Used graph-post.js · Called /v1.0/search/query · Response has hits

### 15 — SP REST search
**Task:** Search using SharePoint REST Search API.
**Checks:** Used sp-get.js · Called /_api/search/query · Response has results

---

## Users & Permissions

### 16 — Current user
**Task:** Get current user's name, email, and ID.
**Checks:** Used sp-get.js or graph-get.js · Shows name and email

### 17 — Search users
**Task:** Find site users or search by name.
**Checks:** Used /siteusers or /users · Shows user list

### 43 — Check permissions
**Task:** Check site role assignments.
**Checks:** Used sp-get.js · Called /roleassignments · Shows roles

### 44 — Send email
**Task:** Send a test email via Graph API.
**Checks:** Used graph-post.js · Called /me/sendMail · Success (202)

### 45 — Send Teams message
**Task:** Send a Teams message via Graph API.
**Checks:** Used graph-post.js · Created chat + sent message · Success

---

## Pages

### 35 — List pages
**Task:** List all site pages with title and filename.
**Checks:** Used sp-get.js · Called Site Pages list items · Shows pages

### 36 — Create page
**Task:** Create a page titled "EVAL_TEST_PAGE" and publish it.
**Checks:** Used sp-post.js · POSTed to /_api/sitepages/pages · Published

### 37 — Edit page
**Task:** Update EVAL_TEST_PAGE title or description.
**Checks:** Used sp-post.js with PATCH · Success

### 38 — Delete page
**Task:** Delete EVAL_TEST_PAGE.
**Checks:** Used DELETE · Page removed

---

## Advanced

### 18 — Recycle bin
**Task:** Get recycle bin contents.
**Checks:** Used sp-get.js · Called /_api/web/recyclebin · Shows items or empty

### 19 — List views
**Task:** Get views for a list.
**Checks:** Used sp-get.js · Called /views · Shows view names and IDs

### 39 — Create rule
**Task:** Create a list rule.
**Checks:** Used sp-post.js · POSTed to /SPListRules · Rule created
**Env-dependent:** If SPListRules returns 404, score ⚠️ PARTIAL — endpoint not available in this environment

### 40 — Delete rule
**Task:** Delete the rule from 39.
**Checks:** Used sp-post.js with DELETE · Success
**Env-dependent:** If eval 39 was PARTIAL (endpoint unavailable), score ⚠️ PARTIAL with same note

### 41 — Navigation
**Task:** Get site navigation nodes.
**Checks:** Used sp-get.js · Called /navigation/quicklaunch · Shows nav items

### 42 — Site features
**Task:** List active site features.
**Checks:** Used sp-get.js · Called /features · Shows feature list

---

## Report

After completing all evals, write `evals/results/report.md`:

```
# Eval Report — [date]

**Site:** [site URL]
**Overall:** [passed]/48 ([percentage]%)

## Summary

| Category | Passed | Total | Score |
|----------|--------|-------|-------|
| Auth | /1 | |
| Discovery | /6 | |
| List CRUD | /14 | |
| Files | /9 | |
| Search | /2 | |
| Users | /5 | |
| Pages | /4 | |
| Advanced | /7 | |

## Results

| # | Eval | Score | Notes |
|---|------|-------|-------|
| 01 | Authenticate | | |
| ... | ... | | |

## Failures
[Details for any ❌ or ⚠️]
```

## Cleanup
Delete all EVAL_TEST_* items, columns, views, lists, pages, folders, and rules created during the run.
