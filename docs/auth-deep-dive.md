# Authentication Deep Dive

A technical deep-dive into how Playwright persistent context authentication works for SharePoint API access.

## How Playwright Persistent Context Auth Works

1. Playwright launches a Chromium-based browser (Microsoft Edge) using `chromium.launchPersistentContext`
2. The persistent context stores its profile at `~/.sharepoint-api-skill/browser-profile/`
3. On first run, the browser opens visibly — user signs into SharePoint
4. The browser profile saves all cookies, localStorage, and session state to disk
5. On subsequent runs, the browser launches headlessly and loads the saved profile
6. Cookies are extracted via `context.cookies()` — the `FedAuth` and `rtFa` cookies are selected
7. These cookies are passed as `Cookie:` header in all SP REST calls

### Why Persistent Context Matters

Unlike regular Playwright contexts that start fresh each time, a persistent context stores its state in a user data directory — just like a normal browser profile. This means:

- **Login persists** — SSO tokens, session cookies, and auth state survive across runs
- **Windows SSO/WAM integration** — if you're logged into Windows with your corp account, SharePoint auth may work automatically (no manual login at all)
- **No app registration** — the browser session has the same permissions as your normal browser
- **No secrets to manage** — no client IDs, client secrets, or certificates

### How Windows SSO/WAM Provides Frictionless Auth

On Windows machines joined to Azure AD (Entra ID), the Web Account Manager (WAM) provides Single Sign-On:

1. When you sign into Windows with your corporate account, WAM caches your auth tokens
2. Edge (built on Chromium) has native WAM integration
3. When Playwright launches Edge with `channel: 'msedge'`, it uses the real Edge binary (not Chromium)
4. Edge's WAM integration picks up your Windows login automatically
5. SharePoint recognizes the WAM-issued tokens and sets session cookies without a manual login prompt

This means on a corp-joined Windows machine, the very first run may complete without any manual login.

## OAuth Token Extraction

In addition to cookies, the auth script extracts OAuth Bearer tokens from the browser session for Graph API and OAuth-only SharePoint endpoints.

### How It Works

1. **Network request interception** — Before navigating to the SP site, a Playwright request listener captures `Authorization: Bearer` headers from requests the page makes to `graph.microsoft.com` and `*.sharepoint.*` during load.

2. **MSAL cache scan** — As a fallback, the script reads the browser's sessionStorage and localStorage for MSAL-cached access token entries (keys containing `accesstoken`, values with `secret` and `expiresOn` fields). Expired tokens are skipped.

3. **Retry with networkidle** — If no Graph token is captured on first navigation, the script reloads the page with `waitUntil: 'networkidle'` to trigger additional API calls.

### Token Properties

| Token | Stored As | Used By | Lifetime |
|-------|-----------|---------|----------|
| GRAPH_TOKEN | `auth.json` + env var | `graph-get.js`, `graph-post.js` | ~60 min |
| SP_TOKEN | `auth.json` + env var | `sp-get.js`, `sp-post.js` (preferred over cookies) | ~60 min |

### Why Both Cookies and Tokens

- **Cookies** (FedAuth, rtFa) — Long-lived (~8-24h), work for all SP REST `/_api/` endpoints except OAuth-only ones.
- **SP_TOKEN** — Required for endpoints like `/_api/v2.1/termstore` that reject cookie auth.
- **GRAPH_TOKEN** — Required for Microsoft Graph API calls (search, email, Teams, file sharing).

Token extraction is best-effort: if the browser session doesn't yield tokens, cookie-based auth still works for SP REST.

## Key SharePoint Cookies

- **FedAuth** — The main authentication cookie. Base64-encoded SAML token. Typically 1000–3000 chars.
- **rtFa** — "Remember the FedAuth" — a refresh/session cookie that works alongside FedAuth.
- Together, these two cookies provide full authenticated access to the SharePoint REST API.

## Cookie vs Token Comparison

| Aspect | Session Cookie (Playwright) | Bearer Token (if available) |
|--------|----------------------------|----------------------------|
| Format | Opaque (FedAuth: base64 XML, rtFa: opaque) | JWT (3 base64 segments) |
| Lifetime | ~8–24 hours | ~60 minutes |
| Refresh | Re-run auth script (instant — uses saved profile) | Requires new token request |
| Scope | Full (same as browser session) | Limited by app registration |
| Used for | SP REST API (`/_api/...`) | SP REST or Microsoft Graph |

## Profile Storage

The browser profile is stored at:

```
~/.sharepoint-api-skill/browser-profile/
```

This directory contains:

- Cookie database
- localStorage / sessionStorage data
- Cached auth tokens
- Browser state (history, preferences)

### Profile Lifecycle

| Event | What Happens |
|-------|-------------|
| First run | Profile created, Edge opens for login |
| Subsequent runs | Profile reused, headless, cookies extracted instantly |
| `--login` | Profile reused but Edge opens visibly for re-login |
| `--logout` | Profile directory deleted entirely |
| Cookies expire | Auth script detects login redirect, falls back to visible login |

## Security Considerations

### Profile on Disk

- The browser profile is stored in your home directory with standard file permissions
- It contains the same data as your normal Edge profile — cookies, cached auth tokens, etc.
- Anyone with access to your home directory can read these cookies
- This is the same security model as using Edge normally
- The profile does NOT contain your password — only session tokens

### Best Practices

- Don't log or commit cookie values
- Re-authenticate periodically (cookies expire)
- Use `--logout` to clear the profile when switching accounts or machines
- The profile directory is excluded from version control by default (it's in your home directory, not the repo)

### Comparison to Previous CDP Approach

| Aspect | Playwright Persistent Context | CDP (previous) |
|--------|-------------------------------|----------------|
| Setup | `npm install` (one-time) | Close all Edge windows, relaunch with debug flag |
| Auth flow | Automatic (profile persists) | Manual (visit site in debug browser every time) |
| Dependencies | Node.js + Playwright | Python 3 + websocket-client (or PowerShell WebSocket) |
| Security | Profile stored at ~/.sharepoint-api-skill/ | Cookies only in env vars (lost on shell close) |
| Reliability | Very high (Playwright manages browser lifecycle) | Fragile (debug port conflicts, silent flag ignore) |
| Login persistence | Yes (profile survives across sessions) | No (must re-login every time Edge restarts) |
