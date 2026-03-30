#!/usr/bin/env node
// ============================================================================
// sp-auth.js — Playwright-based SharePoint authentication
// ============================================================================
// Usage:
//   Bash:       eval $(node scripts/sp-auth.js contoso.sharepoint.com)
//   PowerShell: node scripts/sp-auth.js contoso.sharepoint.com --ps1 | Invoke-Expression
//
// First run: opens Edge for login (one-time)
// Subsequent runs: headless, uses cached profile (instant)
//
// Flags:
//   --login   Force visible browser for re-login
//   --logout  Clear saved browser profile
//   --ps1     Output PowerShell syntax instead of Bash
// ============================================================================
'use strict';

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PROFILE_DIR = path.join(os.homedir(), '.sharepoint-api-skill', 'browser-profile');
const LOGIN_TIMEOUT_MS = 300_000; // 5 minutes for interactive login
const HEADLESS_PROBE_MS = 5_000;  // seconds to wait before falling back to visible

// ── Helpers ──────────────────────────────────────────────────────────────────

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function isLoginUrl(url) {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return host.includes('login.microsoftonline.com')
      || host.includes('login.microsoft.com')
      || host.includes('login.live.com');
  } catch {
    return false;
  }
}

function parseTenantHost(raw) {
  let host = raw.replace(/^https?:\/\//, '').replace(/\/+$/, '');
  return host;
}

function buildCookieString(cookies, tenantHost) {
  // Filter cookies belonging to the tenant domain
  const domainCookies = cookies.filter(c => {
    const d = c.domain.replace(/^\./, '');
    return tenantHost.endsWith(d) || d.endsWith(tenantHost);
  });

  // Prefer known auth cookies, fall back to all domain cookies
  const authNames = new Set(['FedAuth', 'rtFa', 'SPOIDCRL', 'CcsAuth']);
  const authCookies = domainCookies.filter(c => authNames.has(c.name) || c.name.startsWith('FedAuth'));

  const chosen = authCookies.length > 0 ? authCookies : domainCookies;
  return chosen.map(c => `${c.name}=${c.value}`).join('; ');
}

// ── Core auth flow ───────────────────────────────────────────────────────────

async function authenticate(tenantHost, { forceLogin = false } = {}) {
  ensureDir(PROFILE_DIR);

  const siteUrl = `https://${tenantHost}`;

  // First attempt: headless (unless --login forces visible)
  let headless = !forceLogin;
  let context = await chromium.launchPersistentContext(PROFILE_DIR, {
    channel: 'msedge',
    headless,
    args: ['--disable-blink-features=AutomationControlled'],
    viewport: { width: 1280, height: 800 },
  });

  let page = context.pages()[0] || await context.newPage();
  await page.goto(siteUrl, { waitUntil: 'domcontentloaded' });

  // Check if we landed on a login page
  if (headless && isLoginUrl(page.url())) {
    // Wait briefly in case of redirect
    try {
      await page.waitForURL(url => !isLoginUrl(url.toString()), { timeout: HEADLESS_PROBE_MS });
    } catch {
      // Still on login — close headless, relaunch visible
      await context.close();
      process.stderr.write('🔑 Opening Edge for login (one-time)...\n');
      process.stderr.write('   Complete the login in the browser window.\n');

      context = await chromium.launchPersistentContext(PROFILE_DIR, {
        channel: 'msedge',
        headless: false,
        args: ['--disable-blink-features=AutomationControlled'],
        viewport: { width: 1280, height: 800 },
      });

      page = context.pages()[0] || await context.newPage();
      await page.goto(siteUrl, { waitUntil: 'domcontentloaded' });
      headless = false;
    }
  }

  // If visible, wait for user to complete login
  if (!headless && isLoginUrl(page.url())) {
    try {
      await page.waitForURL(url => !isLoginUrl(url.toString()), { timeout: LOGIN_TIMEOUT_MS });
      // Brief pause to let cookies settle
      await page.waitForTimeout(2000);
      process.stderr.write('✅ Login successful. Profile saved.\n');
    } catch {
      process.stderr.write('⚠️  Login timed out or browser was closed.\n');
      await context.close();
      process.exit(1);
    }
  }

  // If we were forced visible (--login) and already authenticated, note it
  if (forceLogin && !isLoginUrl(page.url())) {
    await page.waitForTimeout(1000);
    process.stderr.write('✅ Login successful. Profile saved.\n');
  }

  // Extract cookies
  const allCookies = await context.cookies();
  const cookieStr = buildCookieString(allCookies, tenantHost);

  await context.close();

  if (!cookieStr) {
    process.stderr.write(`ERROR: No cookies found for ${siteUrl}.\n`);
    process.stderr.write('Try running with --login to force a fresh login.\n');
    process.exit(1);
  }

  return { cookieStr, siteUrl };
}

// ── Output formatters ────────────────────────────────────────────────────────

function outputBash(cookieStr, siteUrl) {
  process.stdout.write(`export SP_COOKIES="${cookieStr}";\n`);
  process.stdout.write(`export SP_SITE="${siteUrl}";\n`);
  process.stdout.write(`echo "✅ Authenticated to ${siteUrl}";\n`);
}

function outputPowerShell(cookieStr, siteUrl) {
  process.stdout.write(`$env:SP_COOKIES="${cookieStr}";\n`);
  process.stdout.write(`$env:SP_SITE="${siteUrl}";\n`);
  process.stdout.write(`Write-Host "✅ Authenticated to ${siteUrl}";\n`);
}

// ── CLI entrypoint ───────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const flags = new Set(args.filter(a => a.startsWith('--')));
  const positional = args.filter(a => !a.startsWith('--'));

  const usePowerShell = flags.has('--ps1');
  const forceLogin = flags.has('--login');
  const doLogout = flags.has('--logout');

  if (flags.has('--help') || (positional.length === 0 && !doLogout)) {
    process.stderr.write(`Usage: node sp-auth.js <tenant-hostname> [--login] [--logout] [--ps1]\n`);
    process.stderr.write(`\n`);
    process.stderr.write(`  <tenant-hostname>  e.g. contoso.sharepoint.com\n`);
    process.stderr.write(`  --login            Force visible browser for re-login\n`);
    process.stderr.write(`  --logout           Clear saved browser profile\n`);
    process.stderr.write(`  --ps1              Output PowerShell syntax (default: Bash)\n`);
    process.exit(0);
  }

  // Handle --logout
  if (doLogout) {
    if (fs.existsSync(PROFILE_DIR)) {
      fs.rmSync(PROFILE_DIR, { recursive: true, force: true });
      process.stderr.write('🗑️  Browser profile cleared.\n');
    } else {
      process.stderr.write('ℹ️  No profile found.\n');
    }
    process.exit(0);
  }

  const tenantHost = parseTenantHost(positional[0]);
  const { cookieStr, siteUrl } = await authenticate(tenantHost, { forceLogin });

  if (usePowerShell) {
    outputPowerShell(cookieStr, siteUrl);
  } else {
    outputBash(cookieStr, siteUrl);
  }
}

main().catch(err => {
  process.stderr.write(`ERROR: ${err.message}\n`);
  process.exit(1);
});
