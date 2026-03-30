#!/usr/bin/env node
// ============================================================================
// sp-auth.js — Playwright-based SharePoint authentication
// ============================================================================
// Usage:
//   node scripts/sp-auth.js contoso.sharepoint.com/sites/mysite
//
// First run: opens Edge for login (one-time)
// Subsequent runs: headless, uses cached profile (instant)
//
// Auth is saved to ~/.sharepoint-api-skill/auth.json. All other scripts
// (sp-get.js, sp-post.js) read from that file automatically.
//
// Flags:
//   --login   Force visible browser for re-login
//   --logout  Clear saved browser profile
// ============================================================================
'use strict';

let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  process.stderr.write('ERROR: playwright is not installed.\nRun: npm install    (in the skill directory)\n');
  process.exit(1);
}
const fs = require('fs');
const path = require('path');
const os = require('os');

const DATA_DIR = path.join(os.homedir(), '.sharepoint-api-skill');
const PROFILE_DIR = path.join(DATA_DIR, 'browser-profile');
const AUTH_FILE = path.join(DATA_DIR, 'auth.json');
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

function parseSiteInput(raw) {
  const cleaned = raw.replace(/^https?:\/\//, '').replace(/\/+$/, '');
  const slashIdx = cleaned.indexOf('/');
  if (slashIdx === -1) {
    return { tenantHost: cleaned, sitePath: '' };
  }
  return {
    tenantHost: cleaned.substring(0, slashIdx),
    sitePath: cleaned.substring(slashIdx),
  };
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

async function authenticate(tenantHost, { forceLogin = false, sitePath = '' } = {}) {
  ensureDir(PROFILE_DIR);

  const tenantUrl = `https://${tenantHost}`;
  const siteUrl = sitePath ? `${tenantUrl}${sitePath}` : tenantUrl;

  // First attempt: headless (unless --login forces visible)
  let headless = !forceLogin;
  let context = await chromium.launchPersistentContext(PROFILE_DIR, {
    channel: 'msedge',
    headless,
    args: ['--disable-blink-features=AutomationControlled'],
    viewport: { width: 1280, height: 800 },
  });

  let page = context.pages()[0] || await context.newPage();

  // Intercept bearer tokens from network requests to capture SP tokens.
  const capturedTokens = { sp: null, spScopes: 0 };
  function classifyToken(token) {
    try {
      const payload = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
      const aud = (payload.aud || '').toLowerCase();
      const scopes = (payload.scp || '').split(' ').length;
      if (aud.includes('.sharepoint.')) return { type: 'sp', scopes };
    } catch {}
    return null;
  }
  function installTokenInterceptor(p) {
    p.on('request', request => {
      const auth = request.headers()['authorization'];
      if (!auth?.startsWith('Bearer ')) return;
      const token = auth.substring(7);
      const info = classifyToken(token);
      if (!info) return;
      if (info.type === 'sp' && info.scopes > capturedTokens.spScopes) {
        capturedTokens.sp = token;
        capturedTokens.spScopes = info.scopes;
      }
    });
  }
  installTokenInterceptor(page);

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
      installTokenInterceptor(page); // Re-register on new page
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

  if (!cookieStr) {
    await context.close();
    process.stderr.write(`ERROR: No cookies found for ${tenantUrl}.\n`);
    process.stderr.write('Try running with --login to force a fresh login.\n');
    process.exit(1);
  }

  // Wait for page to fully load (SPFx needs networkidle to fire API calls)
  await page.waitForLoadState('networkidle').catch(() => {});

  // Extract SP token from captured network requests
  let spToken = capturedTokens.sp;

  // If still missing SP token, reload and wait for all network activity
  if (!spToken) {
    try {
      await page.goto(siteUrl, { waitUntil: 'networkidle', timeout: 30000 });
      spToken = spToken || capturedTokens.sp;
    } catch {}
  }

  await context.close();

  // Persist auth to file for cross-process use
  const authData = {
    SP_SITE: siteUrl,
    SP_COOKIES: cookieStr,
    ...(spToken && { SP_TOKEN: spToken }),
  };
  ensureDir(DATA_DIR);
  fs.writeFileSync(AUTH_FILE, JSON.stringify(authData, null, 2) + '\n');

  return { cookieStr, siteUrl, spToken };
}

// ── CLI entrypoint ───────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const flags = new Set(args.filter(a => a.startsWith('--')));
  const positional = args.filter(a => !a.startsWith('--'));

  const forceLogin = flags.has('--login');
  const doLogout = flags.has('--logout');

  if (flags.has('--help') || (positional.length === 0 && !doLogout)) {
    process.stderr.write(`Usage: node sp-auth.js <site-url> [--login] [--logout]\n`);
    process.stderr.write(`\n`);
    process.stderr.write(`  <site-url>  e.g. contoso.sharepoint.com/sites/mysite or contoso.sharepoint.com/teams/myteam\n`);
    process.stderr.write(`  --login     Force visible browser for re-login\n`);
    process.stderr.write(`  --logout    Clear saved browser profile\n`);
    process.stderr.write(`\n`);
    process.stderr.write(`Auth is saved to ~/.sharepoint-api-skill/auth.json.\n`);
    process.stderr.write(`All other scripts (sp-get.js, sp-post.js) read from that file automatically.\n`);
    process.exit(0);
  }

  // Handle --logout
  if (doLogout) {
    let cleared = false;
    if (fs.existsSync(PROFILE_DIR)) {
      fs.rmSync(PROFILE_DIR, { recursive: true, force: true });
      cleared = true;
    }
    if (fs.existsSync(AUTH_FILE)) {
      fs.rmSync(AUTH_FILE);
      cleared = true;
    }
    process.stderr.write(cleared ? '🗑️  Browser profile and auth cleared.\n' : 'ℹ️  No profile found.\n');
    process.exit(0);
  }

  const { tenantHost, sitePath } = parseSiteInput(positional[0]);
  await authenticate(tenantHost, { forceLogin, sitePath });

  process.stderr.write(`✅ Authenticated to ${positional[0]}\n`);
  process.stderr.write(`   Auth saved to ${AUTH_FILE}\n`);
}

main().catch(err => {
  process.stderr.write(`ERROR: ${err.message}\n`);
  process.exit(1);
});
