# SharePoint API Skill — Setup Guide

This guide covers how to authenticate with SharePoint so the skill can make API calls on your behalf.

---

## One-Time Setup

### Install Dependencies

```bash
cd <skill-directory>
npm install
```

This installs Playwright, which is used for browser-based authentication.

### First Authentication

**Bash:**

```bash
source .claude/skills/sharepoint-api/scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite
```

**PowerShell:**

```powershell
. .claude\skills\sharepoint-api\scripts\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite
```

Replace `contoso.sharepoint.com/sites/mysite` with your actual site URL.

On first run, Edge opens a visible browser window. Sign in with your Microsoft account. Once login completes, the browser closes automatically and your session is saved to a local profile.

### Subsequent Runs

Run the same auth command. It launches Edge headlessly (no visible window), reads the saved profile, extracts cookies, and sets environment variables — typically completing in under 2 seconds.

### What Gets Set

| Variable | Description |
|----------|-------------|
| `SP_COOKIES` | FedAuth + rtFa cookies for SharePoint REST API calls |
| `SP_SITE` | Full site URL (e.g., `https://contoso.sharepoint.com/sites/mysite`) |

### Verify

Run a quick test call to confirm everything is working:

```bash
node scripts/sp-get.js "/_api/web?$select=Title"
```

You should see a JSON response containing your site's title.

---

## Login / Logout

### Force Re-Login

If your session expires or you need to switch accounts:

**Bash:**
```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --login
```

**PowerShell:**
```powershell
. .\scripts\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite -Login
```

### Clear Saved Profile

To delete the cached browser profile entirely:

**Bash:**
```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --logout
```

**PowerShell:**
```powershell
. .\scripts\sp-auth-wrapper.ps1 contoso.sharepoint.com/sites/mysite -Logout
```

The profile is stored at `~/.sharepoint-api-skill/browser-profile/`. The `--logout` flag deletes this directory.

---

## Troubleshooting

### "Edge not found" or "Executable doesn't exist"

Playwright requires Microsoft Edge to be installed. Install Edge from [microsoft.com/edge](https://www.microsoft.com/edge).

### "Login loop" — keeps redirecting to login

Your saved session may have expired. Force a fresh login:

```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --login
```

### "No cookies found for tenant"

1. Make sure the site URL is correct (e.g., `contoso.sharepoint.com/sites/mysite`, not just `contoso.com`).
2. Try `--login` to force an interactive login.
3. If using a dogfood tenant, use the full hostname (e.g., `contoso.sharepoint-df.com`).

### "HTTP 401" on API calls

Cookies expired — SharePoint cookies typically last 8–24 hours. Re-run the auth script to get fresh cookies.

### "HTTP 403" on API calls

You do not have permission to the requested resource. Check with your SharePoint administrator to confirm your access level.

### Clear profile and start fresh

```bash
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --logout
source ./scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite --login
```

### Cookie Expiration

SharePoint session cookies typically last **8–24 hours**. When you start seeing `401 Unauthorized` responses, simply re-run the auth script to get fresh cookies. The persistent browser profile means this is instant — no manual login required unless the profile itself expires (typically weeks/months).
