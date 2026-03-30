# SharePoint API Skill

**AI-powered SharePoint for Claude Code, GitHub Copilot, and Codex**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## What It Does

This skill teaches AI coding agents to interact with any SharePoint Online site through REST and Microsoft Graph APIs — 50+ operations, zero app registration, cross-platform.

## Capabilities

### Lists and List Items
- *"Show me all lists on this site with their item counts"*
- *"Get the first 20 items from the Tasks list, sorted by due date"*
- *"Create a new item in the Issues list with Title 'Server outage' and Priority 'High'"*
- *"Update item 42 in the Tasks list — set Status to 'Completed'"*
- *"Delete all items in the TestData list where Status is 'Draft'"*
- *"Run a CAML query on the Orders list to find items created this month"*

### List Schema and Views
- *"Add a Choice column called 'Region' to the Customers list with options North, South, East, West"*
- *"Create a view called 'My Open Items' that filters to items assigned to the current user"*
- *"Show me the schema for the Projects list — all columns with their types"*
- *"Apply column formatting to highlight overdue items in red"*

### Files and Folders
- *"List all files in the Shared Documents library with name and size"*
- *"Upload report.pdf to the Reports folder in the document library"*
- *"Read the contents of config.json from Shared Documents"*
- *"Create a folder called 'Q1 Reports' in the document library"*
- *"Copy budget.xlsx to the Archive folder"*
- *"Show me the version history for proposal.docx"*

### Search
- *"Search for all documents containing 'quarterly review'"*
- *"Find Excel files modified in the last 7 days"*

### Pages
- *"List all site pages with their titles"*
- *"Create a new page called 'Team Updates' and publish it"*
- *"Update the title of the Welcome page"*

### Users and Permissions
- *"Who is the current user?"*
- *"List all site users with their email addresses"*
- *"Show me the role assignments for this site"*

### Site Administration
- *"Get the site title, URL, and description"*
- *"List all active site features"*
- *"Show the quick launch navigation"*
- *"Get the recycle bin contents"*
- *"List content types on the Documents library"*
- *"Get the term store taxonomy"*

### Lists and Libraries Management
- *"Create a new list called 'Project Tracker'"*
- *"Delete the list named Episodes"*

## Install

### Claude Code

```claude
/install supermem613/sharepoint-api-skill
```

### Manual

```bash
git clone https://github.com/supermem613/sharepoint-api-skill
cd sharepoint-api-skill && npm install
```

## Auth

The agent authenticates automatically when the skill is invoked. Playwright launches a persistent Edge browser context that inherits Windows SSO/WAM — first run opens Edge for login (one-time), then it's instant and headless. No client ID, no tenant config, no secrets.

- Credentials persist in `~/.sharepoint-api-skill/auth.json` (works across shell sessions)
- GRAPH_TOKEN extracted automatically from the browser session
- `--login` to force re-login, `--logout` to clear the profile

## Evals

48 evals covering auth, discovery, list CRUD, files, search, users, pages, and advanced operations. Run them against any dev/test site:

```
Run evals/run-evals.md against contoso.sharepoint.com/sites/testsite
```

Results are written to `evals/results/report.md`. See [`evals/run-evals.md`](evals/run-evals.md) for the full eval list and scoring criteria.

> **Warning:** Evals create and delete test data prefixed with `EVAL_TEST_`. Only run against dev/test sites.

## Tests

```bash
npm test                    # Static tests (no network)
npm run test:integration    # Live API tests (requires auth)
```

## Prerequisites

- **Node.js 18+**
- **Microsoft Edge** (Playwright uses your system Edge)
- `npm install` (one-time, installs Playwright)

## License

[MIT](LICENSE)
