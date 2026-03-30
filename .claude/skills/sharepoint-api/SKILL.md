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

## Agent Usage (IMPORTANT — read first)

All script paths below are relative to this skill's base directory. When Claude Code loads this skill, it injects a `Base directory for this skill:` header. Use that value as `SKILL_DIR` in all commands.

**Rules for Claude Code:**

1. **Set `SKILL_DIR`** to the base directory shown above. Use it for every script path.
2. **Omit the leading `/`** from API endpoints — write `_api/web/lists` not `/_api/web/lists`. The scripts prepend it.
3. **Call `node` directly** for auth — don't `source` the bash wrapper. Each Bash invocation is a fresh shell, so env vars from `source` are lost. Auth persists via `~/.sharepoint-api-skill/auth.json`.
4. **Chain auth + query** with `&&` into a single Bash call to minimize permission asks.
5. **Skip auth** if already authenticated to the target site — check `~/.sharepoint-api-skill/auth.json`.

**Single-call pattern** (auth + query combined):
```bash
node "$SKILL_DIR/scripts/sp-auth.js" <hostname/site> >/dev/null && node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists"
```

**Query-only pattern** (when already authenticated):
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists"
```

## Setup

### Prerequisites

- **Node.js** (18+) — for all scripts (auth, REST helpers)
- **Microsoft Edge** — for Playwright persistent context auth (no app registration needed)
- Run `npm install` in the skill directory (one-time, installs Playwright)

### Authenticate

```bash
node "$SKILL_DIR/scripts/sp-auth.js" contoso.sharepoint.com/sites/MySite >/dev/null
```

First run opens Edge for login (one-time). After that, auth is automatic and instant — your login persists in a local browser profile.

Auth credentials are saved to `~/.sharepoint-api-skill/auth.json`, so all subsequent `sp-get.js` / `sp-post.js` calls work automatically — even in separate shell sessions.

**Site paths**: Include the site path after the hostname to target sub-sites:
```bash
node "$SKILL_DIR/scripts/sp-auth.js" contoso.sharepoint.com/teams/MyTeam >/dev/null
```

### Login / Logout (interactive terminal only)

For manual use in a terminal, you can source the bash wrapper:
```bash
source "$SKILL_DIR/scripts/sp-auth-wrapper.sh" contoso.sharepoint.com/sites/mysite --login   # Force re-login
source "$SKILL_DIR/scripts/sp-auth-wrapper.sh" contoso.sharepoint.com/sites/mysite --logout  # Clear saved profile + auth
```

> **Note:** For dogfood/test tenants (e.g., `contoso.sharepoint-df.com`), use the full hostname.

## Helper Scripts

All scripts are in `scripts/` and run on Node.js (18+) — cross-platform, zero npm dependencies.

| Script | Purpose | Usage |
|--------|---------|-------|
| `sp-auth-wrapper.sh` / `.ps1` | Authenticate via Playwright | `source "$SKILL_DIR/scripts/sp-auth-wrapper.sh" contoso.sharepoint.com/sites/mysite` |
| `sp-auth.js` | Core auth engine (called by wrappers) | `node "$SKILL_DIR/scripts/sp-auth.js" contoso.sharepoint.com/sites/mysite` |
| `sp-get.js` | SharePoint REST GET | `node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists"` |
| `sp-post.js` | SharePoint REST POST/PATCH/DELETE | `node "$SKILL_DIR/scripts/sp-post.js" "_api/web/lists" '{"Title":"My List"}'` |

All scripts auto-load auth from `~/.sharepoint-api-skill/auth.json` (written by `sp-auth.js`). Env vars (`SP_SITE`, `SP_COOKIES`) override the file if set.

## Quick Reference — 10 Most Common Operations

### 1. List all lists and libraries
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"
```

### 2. Get items from a list
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists(guid'{listId}')/items?\$select=Title,Id,Status&\$top=100"
```

### 3. Create a list item
```bash
node "$SKILL_DIR/scripts/sp-post.js" "_api/web/lists(guid'{listId}')/items" \
  '{"__metadata":{"type":"SP.Data.{ListName}ListItem"},"Title":"New item","Status":"Active"}'
```
> **Tip:** The `__metadata.type` value is list-specific. Look it up with:
> `node "$SKILL_DIR/scripts/sp-get.js" "_api/web/lists(guid'{listId}')?\$select=ListItemEntityTypeFullName"`

### 4. Update a list item
```bash
node "$SKILL_DIR/scripts/sp-post.js" "_api/web/lists(guid'{listId}')/items({itemId})" \
  '{"Title":"Updated title"}' PATCH
```

### 5. Delete a list item
```bash
node "$SKILL_DIR/scripts/sp-post.js" "_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

### 6. Read a file
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```

### 7. Upload a file
```bash
node "$SKILL_DIR/scripts/sp-post.js" "_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```

### 8. Search for files
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=10"
```

### 9. Get current user
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web/currentuser?\$select=Id,Title,Email"
```

### 10. Get site info
```bash
node "$SKILL_DIR/scripts/sp-get.js" "_api/web?\$select=Title,Url,Description"
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
