---
name: sharepoint-api
description: "Interact with any SharePoint site via REST API — lists, files, search, pages, users, and more. Use when you need to read or modify SharePoint data programmatically without a browser, automate site operations, or query SharePoint content from scripts."
metadata:
  author: "Marcus Markiewicz"
  version: "1.0"
  license: "MIT"
  repo: "https://github.com/supermem613/sharepoint-api-skill"
---

# SharePoint API Skill

Interact with any SharePoint Online site directly via the SharePoint REST API. No browser, no server dependencies — just authenticated HTTP calls.

## Agent Usage (IMPORTANT — read first)

All scripts are in `scripts/` under this skill's base directory. Set `SD` once per session to point there.

**Rules for Claude Code:**

1. **Set `SD`** — `SD="<base directory>/scripts"` (from the `Base directory for this skill:` header above). Use `$SD` for all commands.
2. **Omit the leading `/`** from API endpoints — write `_api/web/lists` not `/_api/web/lists`. The scripts prepend it.
3. **Auth persists** via `~/.sharepoint-api-skill/auth.json` — written by `sp-auth.js`, read automatically by `sp-get.js`/`sp-post.js`.
4. **Chain auth + query** with `&&` into a single call to minimize permission asks.
5. **Skip auth** if already authenticated to the target site — check `~/.sharepoint-api-skill/auth.json`.

**Single-call pattern** (auth + query combined):
```
SD="<base directory>/scripts" && node "$SD/sp-auth.js" <hostname/site> && node "$SD/sp-get.js" "_api/web/lists"
```

**Query-only pattern** (when already authenticated):
```
node "$SD/sp-get.js" "_api/web/lists"
```

## Setup

### Prerequisites

- **Node.js** (18+) — for all scripts (auth, REST helpers)
- **Microsoft Edge** — for Playwright persistent context auth (no app registration needed)
- Run `npm install` in the skill directory (one-time, installs Playwright)

### Authenticate

```
node "$SD/sp-auth.js" contoso.sharepoint.com/sites/MySite
```

First run opens Edge for login (one-time). After that, auth is automatic and instant — your login persists in a local browser profile.

Auth credentials are saved to `~/.sharepoint-api-skill/auth.json`, so all subsequent `sp-get.js` / `sp-post.js` calls work automatically — even in separate shell sessions.

**Site paths**: Include the site path after the hostname to target sub-sites:
```
node "$SD/sp-auth.js" contoso.sharepoint.com/teams/MyTeam
```

### Login / Logout

```
node "$SD/sp-auth.js" contoso.sharepoint.com/sites/mysite --login   # Force re-login
node "$SD/sp-auth.js" contoso.sharepoint.com/sites/mysite --logout  # Clear saved profile + auth
```

> **Note:** For dogfood/test tenants (e.g., `contoso.sharepoint-df.com`), use the full hostname.

## Helper Scripts

All scripts are in `scripts/` and run on Node.js (18+) — cross-platform, zero shell dependencies.

| Script | Purpose | Usage |
|--------|---------|-------|
| `sp-auth.js` | Authenticate via Playwright | `node "$SD/sp-auth.js" contoso.sharepoint.com/sites/mysite` |
| `sp-env.js` | Shared auth loader (reads auth.json or env vars) | Used internally by sp-get/sp-post |
| `sp-fetch.js` | Shared fetch with retry and diagnostics | Used internally by sp-get/sp-post |
| `sp-get.js` | SharePoint REST GET | `node "$SD/sp-get.js" "_api/web/lists"` |
| `sp-post.js` | SharePoint REST POST/PATCH/DELETE | `node "$SD/sp-post.js" "_api/web/lists" '{"Title":"My List"}'` |

All scripts auto-load auth from `~/.sharepoint-api-skill/auth.json` (written by `sp-auth.js`). Env vars (`SP_SITE`, `SP_COOKIES`) override the file if set.

## Quick Reference — 10 Most Common Operations

### 1. List all lists and libraries
```
node "$SD/sp-get.js" "_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"
```

### 2. Get items from a list
```
node "$SD/sp-get.js" "_api/web/lists(guid'{listId}')/items?\$select=Title,Id,Status&\$top=100"
```

### 3. Create a list item
```
node "$SD/sp-post.js" "_api/web/lists(guid'{listId}')/items" \
  '{"__metadata":{"type":"SP.Data.{ListName}ListItem"},"Title":"New item","Status":"Active"}'
```
> **Tip:** The `__metadata.type` value is list-specific. Look it up with:
> `node "$SD/sp-get.js" "_api/web/lists(guid'{listId}')?\$select=ListItemEntityTypeFullName"`

### 4. Update a list item
```
node "$SD/sp-post.js" "_api/web/lists(guid'{listId}')/items({itemId})" \
  '{"Title":"Updated title"}' PATCH
```

### 5. Delete a list item
```
node "$SD/sp-post.js" "_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

### 6. Read a file
```
node "$SD/sp-get.js" "_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```

### 7. Upload a file
```
node "$SD/sp-post.js" "_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```

### 8. Search for files
```
node "$SD/sp-get.js" "_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=10"
```

### 9. Get current user
```
node "$SD/sp-get.js" "_api/web/currentuser?\$select=Id,Title,Email"
```

### 10. Get site info
```
node "$SD/sp-get.js" "_api/web?\$select=Title,Url,Description"
```

## API Selection Rule

This skill uses the SharePoint REST API exclusively. All operations use `sp-get.js` and `sp-post.js` with browser session cookies.

| Use Case | Script |
|----------|--------|
| List CRUD, CAML, views, fields, content types | `sp-get.js` / `sp-post.js` |
| File read/write, folders, rename, move, copy | `sp-get.js` / `sp-post.js` |
| Search | `sp-get.js` (`_api/search/query`) |
| Pages, recycle bin, navigation, features | `sp-get.js` / `sp-post.js` |
| Users, permissions | `sp-get.js` (`_api/web/siteusers`, `_api/web/currentuser`) |
| File versions | `sp-get.js` (`_api/web/lists/.../items({id})/versions`) |

## Reference Files

Load these on demand for detailed API documentation on specific domains:

| File | What It Covers |
|------|---------------|
| [`references/list-operations.md`](references/list-operations.md) | List item CRUD, CAML queries, batch updates, fields, views |
| [`references/file-operations.md`](references/file-operations.md) | Upload, download, copy, move, versions, folders |
| [`references/search.md`](references/search.md) | SP Search, KQL syntax |
| [`references/site-discovery.md`](references/site-discovery.md) | Lists, fields, views, content types, user resolution |
| [`references/page-operations.md`](references/page-operations.md) | Site pages, news posts, page content |
| [`references/user-permissions.md`](references/user-permissions.md) | Users, permissions |
| [`references/advanced-operations.md`](references/advanced-operations.md) | Recycle bin, approvals, workflows, navigation, eSignature |
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
| NL-to-CAML query generation | Redundant — you ARE an LLM | Generate CAML directly using the patterns in [`references/api-patterns.md`](references/api-patterns.md) |
