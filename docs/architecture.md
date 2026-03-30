## Architecture & Design Decisions

### What This Is
A skill that teaches AI agents (Claude Code, GitHub Copilot, Codex) to interact with SharePoint Online via the SharePoint REST API. Rather than wrapping each operation in a fixed tool signature, the skill provides the agent with knowledge about how to call the APIs directly.

### Why a Skill Instead of an MCP Server

The skill approach wins because:
- **Zero runtime dependencies** — no server required at execution time; only Node.js + Playwright for auth
- **Cross-platform** — works on Windows, macOS, Linux
- **Agent flexibility** — the agent composes, retries, and adapts freely
- **LLM-native** — Claude IS an LLM; operations that use LLMs (NL-to-CAML, file classification, column suggestions) are redundant
- **Maintenance** — REST APIs are stable; SKILL.md doesn't need updates when upstream services change

### Auth Architecture

```
┌──────────────────────────────────────────────────┐
│                  Auth Layer                        │
│                                                    │
│  ┌─────────┐  Playwright Persistent  ┌─────────┐ │
│  │ sp-auth  │  Context (msedge)      │ Edge     │ │
│  │ .js      │───────────────────────▶│ Browser  │ │
│  │          │◀── FedAuth + rtFa ─────│ Profile  │ │
│  └─────────┘    cookies              └─────────┘ │
│       │                                           │
│       │  Profile: ~/.sharepoint-api-skill/        │
│       │           browser-profile/                │
└──────────────────────────────────────────────────┘
                    │
                    ▼ SP_COOKIES + SP_SITE
┌──────────────────────────────────────────────────┐
│              HTTP Helper Scripts                   │
│  sp-get, sp-post                                   │
└──────────────────────────────────────────────────┘
                    │
          ┌──────────┼──────────┐
          ▼                     ▼
   ┌──────────┐          ┌───────────┐
   │ SP REST  │          │ SP Search │
   │ /_api/   │          │ /_api/    │
   │ web/...  │          │ search/   │
   └──────────┘          └───────────┘
```

### Skill Loading Architecture

```
Agent loads SKILL.md (~2K tokens)
    │
    ├─ Auth setup (one-time)
    ├─ Quick reference (10 common ops)
    ├─ Script usage patterns
    └─ Reference file index
         │
         └─ On demand: agent loads specific reference file
            ├─ list-operations.md (list CRUD, CAML, views)
            ├─ file-operations.md (files, folders, versions)
            ├─ search.md (SP Search, KQL)
            ├─ site-discovery.md (lists, fields, content types)
            ├─ page-operations.md (pages, news)
            ├─ user-permissions.md (users, permissions)
            ├─ advanced-operations.md (rules, recycle bin)
            └─ api-patterns.md (pagination, $filter, CAML)
```

### Scripts

| Script | Purpose |
|--------|---------|
| `sp-auth.js` | Authenticate via Playwright — writes auth.json |
| `sp-env.js` | Shared auth loader — resolves SP_SITE, SP_COOKIES from env/file |
| `sp-get.js` | SharePoint REST GET |
| `sp-post.js` | SharePoint REST POST/PATCH/DELETE (auto-fetches request digest) |

### Reference Guides

8 domain-specific files loaded on demand by the agent (keeps base token cost low at ~2K):

| Reference | Covers |
|-----------|--------|
| `list-operations.md` | List/item CRUD, views, filters, CAML queries |
| `file-operations.md` | Upload, download, copy, move, versions, folders |
| `search.md` | SP Search, KQL syntax |
| `page-operations.md` | Modern pages, news posts, publishing |
| `user-permissions.md` | Users, permissions |
| `site-discovery.md` | Site properties, lists, fields, content types |
| `api-patterns.md` | OData, batching, throttling, CAML |
| `advanced-operations.md` | Rules, recycle bin, navigation, features |

### Design Decisions Log

| Decision | Chosen | Why |
|----------|--------|-----|
| Skill vs MCP | Skill | Zero deps, cross-platform, agent flexibility |
| Auth method | Playwright persistent context | No app registration, zero IT approval, full SP REST access, persistent login |
| Script language | Node.js only | Cross-platform, no shell dependencies |
| API approach | SP REST | SP REST for all operations, cookies-based auth |
| Token parsing | JSON via Node.js | Built-in, no external tools |
| Reference files | Lazy-loaded | Token efficiency (~2K base vs ~20K all) |

### What This Skill Cannot Do

| Capability | Why | Workaround |
|-----------|-----|-----------|
| RAG-backed grounded Q&A | Requires proprietary backend | Agent reads files + reasons itself |
| Enterprise RAG grounding | Requires proprietary orchestration | SP Search + file content reading |
| Email sending | No SP REST equivalent | Use Outlook or other email tools |
| Teams messaging | No SP REST equivalent | Use Teams directly |
| Sharing links | No SP REST equivalent | Share via SharePoint UI |
| Enterprise-wide search (across all M365) | SP REST search is site-scoped only | Use SharePoint admin or M365 tools |
| UI operations | No browser at runtime | Not needed for CLI agents |
| Server-side code execution | Sandboxed environment | Agent runs code locally |
| NL-to-CAML via LLM | Redundant | Agent generates CAML itself (it IS an LLM) |
