---
name: sharepoint-api
description: "Interact with any SharePoint site via REST and Graph APIs. Covers lists, files, search, pages, users, and more."
metadata:
  author: "Marcus Markiewicz"
  version: "1.0"
  license: "MIT"
  repo: "https://github.com/supermem613/sharepoint-api-skill"
---

# SharePoint API Skill

Interact with any SharePoint Online site directly via SharePoint REST API and Microsoft Graph API. No browser, no server dependencies — just authenticated HTTP calls.

## Setup

### Prerequisites

- **Node.js** (18+) — for all scripts (auth, REST helpers)
- **Microsoft Edge** — for Playwright persistent context auth (no app registration needed)
- Run `npm install` in the skill directory (one-time, installs Playwright)

### Authenticate

```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/MySite
```

First run opens Edge for login (one-time). After that, auth is automatic and instant — your login persists in a local browser profile.

Auth credentials are saved to `~/.sharepoint-api-skill/auth.json`, so all subsequent `sp-get.js` / `sp-post.js` / `graph-get.js` / `graph-post.js` calls work automatically — even in separate shell sessions (no need to `source` again).

The auth script also extracts OAuth tokens (GRAPH_TOKEN, SP_TOKEN) from the browser session for Graph API and OAuth-only SP endpoints. These tokens expire after ~60 minutes; re-run the auth script to refresh.

**Site paths**: Include the site path after the hostname to target sub-sites:
```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/teams/MyTeam
```

### Login / Logout

```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --login   # Force re-login
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --logout  # Clear saved profile + auth
```

> **Note:** For dogfood/test tenants (e.g., `contoso.sharepoint-df.com`), use the full hostname.

### Windows / Git Bash

Git Bash (MSYS2) automatically converts arguments that look like Unix paths, which corrupts SharePoint API endpoints like `/_api/web/lists`. The auth wrapper sets `MSYS_NO_PATHCONV=1` automatically when sourced.

If you run scripts directly without sourcing the wrapper, set it manually:
```bash
export MSYS_NO_PATHCONV=1
```

## Helper Scripts

All scripts are in `scripts/` and run on Node.js (18+) — cross-platform, zero npm dependencies.

| Script | Purpose | Usage |
|--------|---------|-------|
| `sp-auth-wrapper.sh` / `.ps1` | Authenticate via Playwright | `source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite` |
| `sp-auth.js` | Core auth engine (called by wrappers) | `node scripts/sp-auth.js contoso.sharepoint.com/sites/mysite` |
| `sp-get.js` | SharePoint REST GET | `node scripts/sp-get.js "/_api/web/lists"` |
| `sp-post.js` | SharePoint REST POST/PATCH/DELETE | `node scripts/sp-post.js "/_api/web/lists" '{"Title":"My List"}'` |
| `graph-get.js` | Microsoft Graph GET | `node scripts/graph-get.js "/v1.0/me"` |
| `graph-post.js` | Microsoft Graph POST/PATCH/DELETE | `node scripts/graph-post.js "/v1.0/me/sendMail" '{...}'` |

All scripts auto-load auth from `~/.sharepoint-api-skill/auth.json` (written by `sp-auth-wrapper`). Env vars (`SP_SITE`, `SP_COOKIES`, `SP_TOKEN`, `GRAPH_TOKEN`) override the file if set.

## Quick Reference — 10 Most Common Operations

### 1. List all lists and libraries
```bash
node scripts/sp-get.js "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"
```

### 2. Get items from a list
```bash
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/items?\$select=Title,Id,Status&\$top=100"
```

### 3. Create a list item
```bash
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/items" \
  '{"__metadata":{"type":"SP.Data.{ListName}ListItem"},"Title":"New item","Status":"Active"}'
```
> **Tip:** The `__metadata.type` value is list-specific. Look it up with:
> `node scripts/sp-get.js "/_api/web/lists(guid'{listId}')?$select=ListItemEntityTypeFullName"`

### 4. Update a list item
```bash
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/items({itemId})" \
  '{"Title":"Updated title"}' PATCH
```

### 5. Delete a list item
```bash
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

### 6. Read a file
```bash
node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```

### 7. Upload a file
```bash
node scripts/sp-post.js "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```

### 8. Search for files (SP REST — preferred, works with cookies)
```bash
node scripts/sp-get.js "/_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=10"
```

### 8b. Search for files (Graph — requires GRAPH_TOKEN)
```bash
node scripts/graph-post.js "/v1.0/search/query" \
  '{"requests":[{"entityTypes":["driveItem"],"query":{"queryString":"budget report"},"size":10}]}'
```

### 9. Get current user
```bash
node scripts/sp-get.js "/_api/web/currentuser?\$select=Id,Title,Email"
```

### 10. Get site info
```bash
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description"
```

## When to Use SharePoint REST vs Microsoft Graph

| Use Case | API | Auth | Reliability |
|----------|-----|------|-------------|
| List CRUD, CAML, views, fields, content types | **SP REST** | Cookies ✅ | Always works |
| File read/write, folders | **SP REST** | Cookies ✅ | Always works |
| Recycle bin, navigation, features, pages | **SP REST** | Cookies ✅ | Always works |
| Search | **SP REST** (preferred) | Cookies ✅ | Always works |
| Search (enterprise-wide) | **Graph** | Bearer token | Needs GRAPH_TOKEN |
| User profiles, org chart | **Graph** | Bearer token | Needs GRAPH_TOKEN |
| Email, Teams messages | **Graph** | Bearer token | Needs GRAPH_TOKEN |
| Sharing links | **Graph** | Bearer token | Needs GRAPH_TOKEN |
| File versions (Graph) | **Graph** | Bearer token | Needs GRAPH_TOKEN |

**Prefer SP REST** for everything cookies can handle. Use Graph only when SP REST has no equivalent.

> **Auth details:** `sp-auth.js` extracts `GRAPH_TOKEN` from the browser session (best-effort). It is available when MSAL tokens are cached but may not always be present or may expire after ~60 minutes. SP REST operations use browser cookies which are always available after auth. Graph API operations (search, email, Teams, sharing links) require `GRAPH_TOKEN` — if it's missing, use the SP REST alternative where one exists (e.g., `/_api/search/query` instead of Graph search).

## Reference Files

Load these on demand for detailed API documentation on specific domains:

| File | What It Covers |
|------|---------------|
| [`references/list-operations.md`](references/list-operations.md) | List item CRUD, CAML queries, batch updates, fields, views |
| [`references/file-operations.md`](references/file-operations.md) | Upload, download, copy, move, versions, folders |
| [`references/search.md`](references/search.md) | Graph Search, SP Search, KQL syntax |
| [`references/site-discovery.md`](references/site-discovery.md) | Lists, fields, views, taxonomy, user resolution |
| [`references/page-operations.md`](references/page-operations.md) | Site pages, news posts, page content |
| [`references/user-permissions.md`](references/user-permissions.md) | Users, sharing, permissions, email, Teams messages |
| [`references/advanced-operations.md`](references/advanced-operations.md) | Rules, recycle bin, approvals, workflows, eSignature |
| [`references/api-patterns.md`](references/api-patterns.md) | Pagination, $select/$filter, CAML, error handling, batch |

## What This Skill Can't Do (and alternatives)

| Capability | Why Not | Alternative |
|--------------|---------|-------------|
| RAG-backed grounded Q&A over documents | Requires proprietary backend | Read file content directly + reason over it |
| UI-only actions (`navigate_to_url`, `preview_view_changes`) | Require a browser | Not needed for CLI agents |
| Server-side code execution | Sandboxed environment | Run code locally |
| Complex multi-step orchestration (doc-from-chat, template-finder) | Internal workflow services | Compose the individual API calls yourself |
| NL-to-CAML query generation | Redundant — you ARE an LLM | Generate CAML directly using the patterns in `api-patterns.md` |
