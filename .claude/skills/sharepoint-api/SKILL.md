---
name: sharepoint-api
description: "Interact with any SharePoint site via REST API. Covers lists, files, search, pages, users, and more."
metadata:
  author: "Marcus Markiewicz"
  version: "1.0"
  license: "MIT"
  repo: "https://github.com/supermem613/sharepoint-api-skill"
---

# SharePoint API Skill

Interact with any SharePoint Online site directly via the SharePoint REST API. No browser, no server dependencies — just authenticated HTTP calls.

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

Auth credentials are saved to `~/.sharepoint-api-skill/auth.json`, so all subsequent `sp-get.js` / `sp-post.js` calls work automatically — even in separate shell sessions (no need to `source` again).

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

All scripts auto-load auth from `~/.sharepoint-api-skill/auth.json` (written by `sp-auth-wrapper`). Env vars (`SP_SITE`, `SP_COOKIES`) override the file if set.

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

### 8. Search for files
```bash
node scripts/sp-get.js "/_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=10"
```

### 9. Get current user
```bash
node scripts/sp-get.js "/_api/web/currentuser?\$select=Id,Title,Email"
```

### 10. Get site info
```bash
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description"
```

## API Selection Rule

This skill uses the SharePoint REST API exclusively. All operations use `sp-get.js` and `sp-post.js` with browser session cookies.

| Use Case | Script | Auth |
|----------|--------|------|
| List CRUD, CAML, views, fields, content types | `sp-get.js` / `sp-post.js` | Cookies — always works |
| File read/write, folders, rename, move, copy | `sp-get.js` / `sp-post.js` | Cookies — always works |
| Search | `sp-get.js` (`/_api/search/query`) | Cookies — always works |
| Pages, recycle bin, navigation, features | `sp-get.js` / `sp-post.js` | Cookies — always works |
| Users, permissions | `sp-get.js` (`/siteusers`, `/currentuser`) | Cookies — always works |
| File versions | `sp-get.js` (`/items({id})/versions`) | Cookies — always works |

## Reference Files

Load these on demand for detailed API documentation on specific domains:

| File | What It Covers |
|------|---------------|
| [`references/list-operations.md`](references/list-operations.md) | List item CRUD, CAML queries, batch updates, fields, views |
| [`references/file-operations.md`](references/file-operations.md) | Upload, download, copy, move, versions, folders |
| [`references/search.md`](references/search.md) | SP Search, KQL syntax |
| [`references/site-discovery.md`](references/site-discovery.md) | Lists, fields, views, taxonomy, user resolution |
| [`references/page-operations.md`](references/page-operations.md) | Site pages, news posts, page content |
| [`references/user-permissions.md`](references/user-permissions.md) | Users, permissions |
| [`references/advanced-operations.md`](references/advanced-operations.md) | Rules, recycle bin, approvals, workflows, eSignature |
| [`references/api-patterns.md`](references/api-patterns.md) | Pagination, $select/$filter, CAML, error handling, batch |

## What This Skill Can't Do (and alternatives)

| Capability | Why Not | Alternative |
|--------------|---------|-------------|
| Email sending | No SP REST equivalent | Use Outlook or other email tools |
| Teams messaging | No SP REST equivalent | Use Teams directly |
| Sharing links | No SP REST equivalent | Share via SharePoint UI |
| Enterprise-wide search (across all M365) | SP REST search is site-scoped only | Use SharePoint admin or M365 tools |
| RAG-backed grounded Q&A over documents | Requires proprietary backend | Read file content directly + reason over it |
| UI-only actions (`navigate_to_url`, `preview_view_changes`) | Require a browser | Not needed for CLI agents |
| Server-side code execution | Sandboxed environment | Run code locally |
| Complex multi-step orchestration (doc-from-chat, template-finder) | Internal workflow services | Compose the individual API calls yourself |
| NL-to-CAML query generation | Redundant — you ARE an LLM | Generate CAML directly using the patterns in `api-patterns.md` |
