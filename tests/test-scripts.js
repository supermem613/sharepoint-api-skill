#!/usr/bin/env node
// Dry-run script validation — no network calls
// Run: node --test tests/test-scripts.js

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { execSync } = require('node:child_process');
const { existsSync, readFileSync } = require('node:fs');
const { join } = require('node:path');

const scriptsDir = join(__dirname, '..', '.claude', 'skills', 'sharepoint-api', 'scripts');

/**
 * Run a Node.js script in a child process with a clean env.
 * Returns { exitCode, stdout, stderr }.
 */
function runScript(scriptName, args = [], env = {}) {
  const scriptPath = join(scriptsDir, scriptName);
  // Use a fake HOME so sp-env.js can't load cached auth.json
  const fakeHome = join(__dirname, '.test-home');
  const cleanEnv = {
    PATH: process.env.PATH,
    HOME: fakeHome,
    USERPROFILE: fakeHome,
    HOMEDRIVE: fakeHome.slice(0, 2),
    HOMEPATH: fakeHome.slice(2),
    SystemRoot: process.env.SystemRoot || '',
    ...env
  };
  try {
    const stdout = execSync(`node "${scriptPath}" ${args.map(a => `"${a}"`).join(' ')}`, {
      env: cleanEnv, encoding: 'utf8', timeout: 10000, stdio: ['pipe', 'pipe', 'pipe']
    });
    return { exitCode: 0, stdout, stderr: '' };
  } catch (e) {
    return { exitCode: e.status ?? 1, stdout: e.stdout ?? '', stderr: e.stderr ?? '' };
  }
}

/**
 * Read script source for static analysis tests.
 */
function readScript(scriptName) {
  return readFileSync(join(scriptsDir, scriptName), 'utf8');
}

// ============================================================================
// 1. File existence
// ============================================================================
describe('File existence', () => {
  for (const s of ['sp-get.js', 'sp-post.js', 'sp-auth.js', 'sp-env.js', 'sp-fetch.js']) {
    it(`${s} exists`, () => {
      assert.ok(existsSync(join(scriptsDir, s)), `${s} not found`);
    });
  }
});

// ============================================================================
// 2. Shebang line
// ============================================================================
describe('Has shebang line', () => {
  for (const s of ['sp-get.js', 'sp-post.js', 'sp-auth.js', 'sp-env.js']) {
    it(`${s} has node shebang`, () => {
      const first = readScript(s).split(/\r?\n/)[0];
      assert.match(first, /node/, `${s} should have node shebang`);
    });
  }
});

// ============================================================================
// 3. Error on missing arguments
// ============================================================================
describe('Error on missing arguments', () => {
  it('sp-get.js fails with no args', () => {
    const r = runScript('sp-get.js');
    assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit code');
  });

  it('sp-post.js fails with no args', () => {
    const r = runScript('sp-post.js');
    assert.notStrictEqual(r.exitCode, 0, 'Expected non-zero exit code');
  });

});

// ============================================================================
// 4. Error on missing environment variables
// ============================================================================
describe('Error on missing environment variables', () => {
  it('sp-get.js fails when SP_SITE is missing', () => {
    const r = runScript('sp-get.js', ['/_api/web'], { SP_TOKEN: 'fake' });
    assert.notStrictEqual(r.exitCode, 0);
    assert.match(r.stderr, /SP_SITE/, 'Error should mention SP_SITE');
  });

  it('sp-get.js fails when SP_TOKEN and SP_COOKIES are both missing', () => {
    const r = runScript('sp-get.js', ['/_api/web'], { SP_SITE: 'https://test.sharepoint.com/sites/testsite' });
    assert.notStrictEqual(r.exitCode, 0);
    assert.match(r.stderr, /auth/, 'Error should mention auth');
  });

  it('sp-post.js fails when SP_SITE is missing', () => {
    const r = runScript('sp-post.js', ['/_api/web/lists', '{}'], { SP_TOKEN: 'fake' });
    assert.notStrictEqual(r.exitCode, 0);
    assert.match(r.stderr, /SP_SITE/, 'Error should mention SP_SITE');
  });

  it('sp-post.js fails when SP_TOKEN and SP_COOKIES are both missing', () => {
    const r = runScript('sp-post.js', ['/_api/web/lists', '{}'], { SP_SITE: 'https://test.sharepoint.com/sites/testsite' });
    assert.notStrictEqual(r.exitCode, 0);
    assert.match(r.stderr, /auth/, 'Error should mention auth');
  });

});

// ============================================================================
// 5. Helpful error messages reference sp-auth
// ============================================================================
describe('Helpful error messages reference sp-auth', () => {
  it('sp-get.js error mentions sp-auth', () => {
    const r = runScript('sp-get.js', ['/_api/web']);
    assert.match(r.stderr, /sp-auth/, 'Error should reference sp-auth');
  });

  it('sp-post.js error mentions sp-auth', () => {
    const r = runScript('sp-post.js', ['/_api/web', '{}']);
    assert.match(r.stderr, /sp-auth/, 'Error should reference sp-auth');
  });

});

// ============================================================================
// 6. sp-auth.js validation
// ============================================================================
describe('sp-auth.js validation', () => {
  const content = readScript('sp-auth.js');

  it('sp-auth.js uses playwright', () => {
    assert.match(content, /playwright/, 'sp-auth.js should use playwright');
  });

  it('sp-auth.js handles --login flag', () => {
    assert.match(content, /--login/, 'sp-auth.js should handle --login flag');
  });

  it('sp-auth.js handles --logout flag', () => {
    assert.match(content, /--logout/, 'sp-auth.js should handle --logout flag');
  });

  it('sp-auth.js writes auth.json', () => {
    assert.match(content, /auth\.json/, 'sp-auth.js should write auth.json');
  });

  it('sp-auth.js has protocol strip logic', () => {
    assert.match(content, /https?:\/\//, 'sp-auth.js should have protocol stripping');
  });
});

// ============================================================================
// 7. sp-env.js validation
// ============================================================================
describe('sp-env.js validation', () => {
  const content = readScript('sp-env.js');

  it('reads from auth.json', () => {
    assert.match(content, /auth\.json/, 'sp-env.js should read auth.json');
  });

  it('checks environment variables first', () => {
    assert.match(content, /process\.env/, 'sp-env.js should check process.env');
  });
});

// ============================================================================
// 8. No shell scripts in scripts directory
// ============================================================================
describe('No shell scripts', () => {
  it('no .sh files in scripts directory', () => {
    const files = require('fs').readdirSync(scriptsDir);
    const shFiles = files.filter(f => f.endsWith('.sh'));
    assert.deepStrictEqual(shFiles, [], `Unexpected .sh files: ${shFiles.join(', ')}`);
  });

  it('no .ps1 files in scripts directory', () => {
    const files = require('fs').readdirSync(scriptsDir);
    const ps1Files = files.filter(f => f.endsWith('.ps1'));
    assert.deepStrictEqual(ps1Files, [], `Unexpected .ps1 files: ${ps1Files.join(', ')}`);
  });
});

// ============================================================================
// 9. sp-post.js method override
// ============================================================================
describe('sp-post.js method override', () => {
  const content = readScript('sp-post.js');

  it('accepts 3rd argument for method override', () => {
    assert.match(content, /methodOverride|argv\[4\]/, 'sp-post.js should accept a 3rd positional argument for method override');
  });

  it('supports PATCH method', () => {
    assert.match(content, /PATCH/, 'sp-post.js should reference PATCH method');
  });

  it('supports DELETE method', () => {
    assert.match(content, /DELETE/, 'sp-post.js should reference DELETE method');
  });

  it('sets X-HTTP-Method header for override', () => {
    assert.match(content, /X-HTTP-Method/, 'sp-post.js should set X-HTTP-Method header');
  });
});

// ============================================================================
// 10. sp-auth.js token extraction from browser session
// ============================================================================
describe('sp-auth.js token extraction', () => {
  const content = readScript('sp-auth.js');

  it('intercepts network requests for Bearer tokens', () => {
    assert.match(content, /\.on\(['"]request['"]/, 'sp-auth.js should register request interceptor');
  });

  it('captures SP tokens from sharepoint requests', () => {
    assert.match(content, /\.sharepoint\./, 'sp-auth.js should look for SP tokens');
  });

  it('outputs SP_TOKEN in auth.json', () => {
    assert.match(content, /SP_TOKEN/, 'sp-auth.js should save SP_TOKEN');
  });

  it('does not use any external OAuth client IDs', () => {
    assert.doesNotMatch(content, /04b07795-8ddb-461a-bbee-02f9e1bf7b46/,
      'sp-auth.js must not use Azure CLI client ID');
  });
});

// ============================================================================
// 11. All scripts are Node.js only
// ============================================================================
describe('All scripts are Node.js', () => {
  it('every file in scripts/ is a .js file', () => {
    const files = require('fs').readdirSync(scriptsDir);
    for (const f of files) {
      assert.ok(f.endsWith('.js'), `Non-JS file found: ${f}`);
    }
  });
});

// ============================================================================
// 12. sp-fetch.js validation
// ============================================================================
describe('sp-fetch.js validation', () => {
  const content = readScript('sp-fetch.js');

  it('exports spFetch function', () => {
    assert.match(content, /spFetch/, 'sp-fetch.js should export spFetch');
  });

  it('has retry logic', () => {
    assert.match(content, /RETRYABLE|retry/i, 'sp-fetch.js should have retry logic');
  });

  it('walks error cause chain', () => {
    assert.match(content, /\.cause/, 'sp-fetch.js should walk error cause chain');
  });

  it('produces actionable hints', () => {
    assert.match(content, /Hint:/, 'sp-fetch.js should include hints in error messages');
  });
});

// ============================================================================
// 13. No external npm dependencies (require of local sp-env is OK)
// ============================================================================
describe('No external npm dependencies', () => {
  for (const s of ['sp-get.js', 'sp-post.js']) {
    it(`${s} only requires local modules`, () => {
      const content = readScript(s);
      // Should not require any npm packages (only ./sp-env is allowed)
      const requires = content.match(/require\s*\(\s*['"]([^'"]+)['"]\s*\)/g) || [];
      for (const r of requires) {
        assert.match(r, /['"]\.\//, `${s} should only require local modules, found: ${r}`);
      }
    });
  }
});
