# 🏢 SharePoint API Skill

**AI-powered SharePoint for Claude Code, GitHub Copilot, and Codex**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## What It Does

This skill teaches AI coding agents to interact with any SharePoint Online site through REST and Microsoft Graph APIs.

- **Full CRUD** on lists, list items, files, folders, pages, and site columns
- **Search, users, and permissions** — everything the SharePoint REST API exposes
- **Covers 50+ SharePoint operations** via REST and Graph API calls
- **Zero app registration** — authenticates via Playwright persistent browser context
- **Cross-platform** — all scripts are Node.js (works everywhere Node 18+ is installed)

## Install

### Claude Code (recommended)

```claude
/install supermem613/sharepoint-api-skill
```

### CLI Installer (any platform)

```bash
npx sharepoint-api-skill init --ai claude     # Claude Code
npx sharepoint-api-skill init --ai copilot    # GitHub Copilot
npx sharepoint-api-skill init --ai codex      # Codex
npx sharepoint-api-skill init --ai all        # All platforms
```

### Manual

```bash
git clone https://github.com/supermem613/sharepoint-api-skill
# Copy .claude/skills/sharepoint-api/ into your project's .claude/skills/
```

## Quick Start

```bash
# 1. Install dependencies (one-time)
npm install

# 2. Authenticate (first run opens Edge for login, then it's instant)
source .claude/skills/sharepoint-api/scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite

# 3. Ask your AI agent anything
#    "List all documents on this SharePoint site"
#    "Create a new list called 'Project Tracker' with columns Status and Owner"
#    "Find all files modified in the last 7 days"
```

## Auth

Playwright launches a persistent Edge browser context that inherits Windows SSO/WAM auth. First run opens a visible Edge window for login; subsequent runs are headless and instant. No client ID, no tenant config, no secrets to manage. Your login persists in a local browser profile at `~/.sharepoint-api-skill/browser-profile/`.

## What's Included

### Helper Scripts (7)

Five Node.js scripts (cross-platform, zero npm dependencies) plus two thin shell wrappers for auth:

| Script | Purpose |
|--------|---------|
| `sp-auth-wrapper.sh` / `.ps1` | Authenticate via Playwright persistent context |
| `sp-auth.js` | Core auth engine (called by wrappers) |
| `sp-get.js` | SharePoint REST GET requests |
| `sp-post.js` | SharePoint REST POST/PATCH/DELETE requests |
| `graph-get.js` | Microsoft Graph GET requests |
| `graph-post.js` | Microsoft Graph POST/PATCH/DELETE requests |

### Reference Guides (8)

Each file provides detailed API documentation for a specific domain:

| Reference | Covers |
|-----------|--------|
| `list-operations.md` | List and list-item CRUD, views, filters, CAML queries |
| `file-operations.md` | Upload, download, copy, move, versions, folders |
| `search.md` | Graph Search, SP Search, KQL syntax |
| `page-operations.md` | Modern pages, news posts, publishing |
| `user-permissions.md` | Users, sharing, permissions, email, Teams |
| `site-discovery.md` | Site properties, lists, fields, taxonomy |
| `api-patterns.md` | OData conventions, batching, throttling, CAML |
| `advanced-operations.md` | Rules, recycle bin, approvals, navigation, eSignature |

## API Coverage

| Category | Status | Examples |
|----------|--------|----------|
| Lists & list items | ✅ Full | Create, read, update, delete, filter, expand |
| Files & folders | ✅ Full | Upload, download, copy, move, checkout, versions |
| Search | ✅ Full | KQL queries, result refinement, people search |
| Users & permissions | ✅ Full | Site users, groups, role assignments, sharing |
| Pages | ✅ Full | Modern pages, web parts, publish/unpublish |
| Site administration | ✅ Full | Properties, features, content types, columns |
| Batching | ✅ Full | OData `$batch` for multi-operation calls |
| RAG / AI-generated answers | ❌ N/A | Requires proprietary backend — agent reads files + reasons directly |
| UI-only actions | ❌ N/A | Actions that require browser interaction |

## Repo Structure

```bash
.claude/skills/sharepoint-api/
├── SKILL.md              ← Skill entry point (loaded by AI agents)
├── scripts/              ← Helper scripts (Node.js + shell auth wrappers)
└── references/           ← 8 domain reference guides
```

## Prerequisites

- **Node.js** (18+) — for all scripts (auth + REST helpers)
- **Microsoft Edge** — Playwright uses your system Edge for auth
- **No app registration** — uses your existing browser session via persistent context
- Run `npm install` once to install Playwright

## Contributing

Contributions are welcome! Open an issue or submit a pull request.

## License

[MIT](LICENSE)
