# Contributing

Guide for engineers working on the SharePoint API Skill.

---

## Quick Start

```bash
git clone https://github.com/supermem613/sharepoint-api-skill
cd sharepoint-api-skill
npm install
```

**Prerequisites:** Node.js 18+, Microsoft Edge (for Playwright auth).

## Project Structure

```
.claude/skills/sharepoint-api/
  SKILL.md              # Agent-facing skill definition (~2K tokens)
  scripts/
    sp-auth.js          # Playwright persistent-context auth
    sp-env.js           # Shared auth loader (reads auth.json or env vars)
    sp-fetch.js         # Shared fetch with retry and diagnostic errors
    sp-get.js           # SharePoint REST GET
    sp-post.js          # SharePoint REST POST/PATCH/DELETE
  references/           # Domain-specific API docs (lazy-loaded by agent)
docs/                   # Human-facing documentation
evals/
  run-evals.md          # 42 evals — agent-executable spec
tests/
  test-scripts.js       # Static validation (no network)
  test-integration.js   # Live API tests (requires auth)
```

## Architecture

This is a **skill**, not an MCP server. The agent reads `SKILL.md`, learns the API patterns, and calls `sp-get.js`/`sp-post.js` directly. No runtime server, no tool registration.

**Auth flow:** Playwright launches Edge with a persistent browser profile (`~/.sharepoint-api-skill/browser-profile/`). On first run, the user logs in visually. After that, auth is headless and instant — cookies are extracted and saved to `~/.sharepoint-api-skill/auth.json`. No app registration, no client IDs, no secrets.

**Token budget:** `SKILL.md` is kept small (~2K tokens). The 8 reference files in `references/` are loaded on demand by the agent only when needed, keeping the base cost low.

See [`docs/architecture.md`](docs/architecture.md) for diagrams and design decisions.

## Development Workflow

### Running Tests

```bash
npm test                    # Static validation — no network, no auth
npm run test:integration    # Live API tests — requires auth to a real site
```

Static tests (`test-scripts.js`) validate file existence, shebangs, error messages, module structure, and that scripts only require local modules (no npm deps in sp-get/sp-post/sp-fetch).

### Running Evals

Evals test all 42 SharePoint operations against a live site. They are defined in `evals/run-evals.md` as an agent-executable spec — tell your AI agent:

```
Run evals/run-evals.md against contoso.sharepoint.com/sites/testsite
```

Results are written to `evals/results/report.md`.

> **Warning:** Evals create and delete test data prefixed with `SHAREPOINT_API_SKILL_EVAL_`. Only run against dev/test sites.

### Authenticating for Development

```bash
node .claude/skills/sharepoint-api/scripts/sp-auth.js contoso.sharepoint.com/sites/mysite
```

First run opens Edge for login. After that, re-running the command refreshes cookies headlessly in ~2 seconds. Cookies last 8-24 hours. Use `--login` to force interactive login, `--logout` to clear the profile.

For dogfood tenants, use the full hostname (e.g., `contoso.sharepoint-df.com`).

## Modifying Scripts

All scripts are in `.claude/skills/sharepoint-api/scripts/`. Rules:

1. **No npm dependencies** in sp-get, sp-post, sp-fetch, sp-env. Only local `./` requires and Node built-ins. The test suite enforces this.
2. **sp-fetch.js** is the shared fetch layer. All HTTP calls in sp-get and sp-post go through `spFetch()`, which handles retry on transient errors and produces diagnostic error messages. Don't bypass it.
3. **sp-env.js** is the auth resolver. It checks env vars first (`SP_SITE`, `SP_COOKIES`, `SP_TOKEN`), then falls back to `~/.sharepoint-api-skill/auth.json`. Don't duplicate this logic.
4. **Cross-platform.** No shell dependencies, no OS-specific paths in scripts. Node.js only.

## Modifying SKILL.md

`SKILL.md` is what the agent reads. It's the most sensitive file in the repo — small changes affect every agent interaction.

- Keep it under ~2K tokens. Move detailed API docs to `references/`.
- Use `$SD` (not `$SKILL_DIR`) in all command examples. The agent sets `SD` once per session pointing to the scripts directory.
- Test changes by invoking the skill from Claude Code and observing agent behavior.

## Modifying Reference Files

The 8 files in `references/` are loaded on demand when the agent needs domain-specific knowledge.

| File | Covers |
|------|--------|
| `list-operations.md` | List/item CRUD, CAML, views, fields |
| `file-operations.md` | Upload, download, copy, move, versions, folders |
| `search.md` | SP Search, KQL syntax |
| `site-discovery.md` | Site properties, lists, fields, content types |
| `page-operations.md` | Modern pages, news posts |
| `user-permissions.md` | Users, permissions, role assignments |
| `advanced-operations.md` | Rules, recycle bin, navigation, features |
| `api-patterns.md` | OData, $select/$filter, CAML, batch, pagination |

When adding a new operation: add it to the appropriate reference file, add a row to `docs/api-coverage.md`, and if it's common enough, add it to the quick reference in `SKILL.md`.

## Adding Evals

Evals live in `evals/run-evals.md`. Each eval has:

- A number and name
- The exact command to run
- A pass condition
- Cleanup instructions (if the eval creates data)

All test data must be prefixed with `SHAREPOINT_API_SKILL_EVAL_` so it's identifiable and cleanable. Evals that depend on environment-specific features (e.g., rules) should be marked `env-dependent` and scored as PARTIAL when unavailable.

## Code Style

- `'use strict'` at the top of every script
- Shebang line (`#!/usr/bin/env node`) on every script
- Errors go to stderr, data goes to stdout
- Silence means success — no verbose output by default
- No comments explaining obvious code. Comment intent, not mechanics.
