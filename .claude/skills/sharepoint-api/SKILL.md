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

- **Node.js** (18+) — for the auth script
- **Microsoft Edge** — for Playwright persistent context auth (no app registration needed)
- Run `npm install` in the skill directory (one-time, installs Playwright)

### Authenticate

**Bash:**
```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com
```

**PowerShell:**
```powershell
. .\scripts\sp-auth-wrapper.ps1 contoso.sharepoint.com
```

First run opens Edge for login (one-time). After that, auth is automatic and instant — your login persists in a local browser profile.

This extracts session cookies via Playwright and sets `SP_COOKIES` and `SP_SITE`. You get full SP REST API access — same permissions as your browser session.

### Login / Logout

```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com --login   # Force re-login
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com --logout  # Clear saved profile
```

> **Note:** For dogfood/test tenants (e.g., `contoso.sharepoint-df.com`), use the full hostname.

## Helper Scripts

All scripts are in `scripts/`. Each has a `.sh` (bash) and `.ps1` (PowerShell) variant.

| Script | Purpose | Usage |
|--------|---------|-------|
| `sp-auth-wrapper` | Authenticate via Playwright | `source ./sp-auth-wrapper.sh contoso.sharepoint.com` |
| `sp-get` | SharePoint REST GET | `./sp-get.sh "/_api/web/lists"` |
| `sp-post` | SharePoint REST POST/PATCH/DELETE | `./sp-post.sh "/_api/web/lists" '{"Title":"My List"}'` |
| `graph-get` | Microsoft Graph GET | `./graph-get.sh "/v1.0/me"` |
| `graph-post` | Microsoft Graph POST/PATCH/DELETE | `./graph-post.sh "/v1.0/me/sendMail" '{...}'` |

`sp-get` and `sp-post` use the `SP_COOKIES` set by `sp-auth-wrapper`. They also support `SP_TOKEN` (bearer) if set.

## Quick Reference — 10 Most Common Operations

### 1. List all lists and libraries
```bash
./sp-get.sh "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"
```

### 2. Get items from a list
```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$select=Title,Id,Status&\$top=100"
```

### 3. Create a list item
```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items" \
  '{"__metadata":{"type":"SP.Data.{ListName}ListItem"},"Title":"New item","Status":"Active"}'
```

### 4. Update a list item
```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})" \
  '{"Title":"Updated title"}' PATCH
```

### 5. Delete a list item
```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

### 6. Read a file
```bash
./sp-get.sh "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```

### 7. Upload a file
```bash
./sp-post.sh "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```

### 8. Search for files (Graph)
```bash
./graph-post.sh "/v1.0/search/query" \
  '{"requests":[{"entityTypes":["driveItem"],"query":{"queryString":"budget report"},"size":10}]}'
```

### 9. Get current user
```bash
./sp-get.sh "/_api/web/currentuser?\$select=Id,Title,Email"
```

### 10. Get site info
```bash
./sp-get.sh "/_api/web?\$select=Title,Url,Description"
```

## When to Use SharePoint REST vs Microsoft Graph

| Use Case | API | Prefix |
|----------|-----|--------|
| List item CRUD, CAML queries, views, fields, content types | **SP REST** | `/_api/web/...` |
| File content, search, email, Teams, user profiles, sharing | **Graph** | `/v1.0/...` |
| Recycle bin, navigation, site features, request digest | **SP REST** | `/_api/web/...` |
| OneDrive operations, cross-site file operations | **Graph** | `/v1.0/drives/...` |

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
