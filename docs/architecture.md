## Architecture & Design Decisions

### What This Is
A skill that teaches AI agents (Claude Code, GitHub Copilot, Codex) to interact with SharePoint Online via REST and Graph APIs. Rather than wrapping each operation in a fixed tool signature, the skill provides the agent with knowledge about how to call the APIs directly.

### Why a Skill Instead of an MCP Server

The skill approach wins because:
- **Zero runtime dependencies** — no server required at execution time; only Node.js + Playwright for auth
- **Cross-platform** — works on Windows, macOS, Linux
- **Agent flexibility** — the agent composes, retries, and adapts freely
- **LLM-native** — Claude IS an LLM; operations that use LLMs (NL-to-CAML, file classification, column suggestions) are redundant
- **Maintenance** — REST/Graph APIs are stable; SKILL.md doesn't need updates when upstream services change

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
│  sp-get, sp-post, graph-get, graph-post           │
└──────────────────────────────────────────────────┘
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
   ┌──────────┐ ┌────────┐ ┌───────────┐
   │ SP REST  │ │ Graph  │ │ SP Search │
   │ /_api/   │ │ /v1.0/ │ │ /_api/    │
   │ web/...  │ │ sites/ │ │ search/   │
   └──────────┘ └────────┘ └───────────┘
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
            ├─ search.md (Graph Search, KQL)
            ├─ site-discovery.md (lists, fields, taxonomy)
            ├─ page-operations.md (pages, news)
            ├─ user-permissions.md (users, sharing, email)
            ├─ advanced-operations.md (rules, recycle bin)
            └─ api-patterns.md (pagination, $filter, CAML)
```

### Design Decisions Log

| Decision | Chosen | Why |
|----------|--------|-----|
| Skill vs MCP | Skill | Zero deps, cross-platform, agent flexibility |
| Auth method | Playwright persistent context | No app registration, zero IT approval, full SP REST access, persistent login |
| Script language | Both bash + PowerShell + Node.js | Cross-platform requirement |
| API approach | SP REST + Graph | SP REST for lists, Graph for search/files |
| Token parsing | jq with sed fallback | Portable, no additional Python dependency |
| Reference files | Lazy-loaded | Token efficiency (~2K base vs ~20K all) |

### What This Skill Cannot Do

| Capability | Why | Workaround |
|-----------|-----|-----------|
| RAG-backed grounded Q&A | Requires proprietary backend | Agent reads files + reasons itself |
| Enterprise RAG grounding | Requires proprietary orchestration | Graph Search + file content reading |
| UI operations | No browser at runtime | Not needed for CLI agents |
| Server-side code execution | Sandboxed environment | Agent runs code locally |
| NL-to-CAML via LLM | Redundant | Agent generates CAML itself (it IS an LLM) |
