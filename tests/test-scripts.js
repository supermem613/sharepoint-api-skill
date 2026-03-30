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
  for (const s of ['sp-get.js', 'sp-post.js', 'sp-auth.js']) {
    it(`${s} exists`, () => {
      assert.ok(existsSync(join(scriptsDir, s)), `${s} not found`);
    });
  }

  for (const s of ['sp-auth-wrapper.ps1', 'sp-auth-wrapper.sh']) {
    it(`${s} exists`, () => {
      assert.ok(existsSync(join(scriptsDir, s)), `${s} not found`);
    });
  }
});

// ============================================================================
// 2. Shebang line
// ============================================================================
describe('Has shebang line', () => {
  for (const s of ['sp-get.js', 'sp-post.js', 'sp-auth.js']) {
    it(`${s} has node shebang`, () => {
      const first = readScript(s).split(/\r?\n/)[0];
      assert.match(first, /node/, `${s} should have node shebang`);
    });
  }

  it('sp-auth-wrapper.sh has #!/bin/bash shebang', () => {
    const first = readScript('sp-auth-wrapper.sh').split(/\r?\n/)[0];
    assert.match(first, /^#!\/bin\/bash/, 'sp-auth-wrapper.sh should have #!/bin/bash shebang');
  });
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

  it('sp-auth.js handles --ps1 flag', () => {
    assert.match(content, /--ps1/, 'sp-auth.js should handle --ps1 flag');
  });

  it('sp-auth.js has protocol strip logic', () => {
    assert.match(content, /https?:\/\//, 'sp-auth.js should have protocol stripping');
  });
});

// ============================================================================
// 7. sp-auth-wrapper.ps1 validation
// ============================================================================
describe('sp-auth-wrapper.ps1 validation', () => {
  const content = readScript('sp-auth-wrapper.ps1');

  it('has param block', () => {
    assert.match(content, /^\s*param\s*\(/m, 'sp-auth-wrapper.ps1 should have param() block');
  });

  it('calls sp-auth.js', () => {
    assert.match(content, /sp-auth\.js/, 'sp-auth-wrapper.ps1 should call sp-auth.js');
  });

  it('passes --ps1 flag', () => {
    assert.match(content, /--ps1/, 'sp-auth-wrapper.ps1 should pass --ps1 flag');
  });
});

// ============================================================================
// 8. sp-auth-wrapper.sh validation
// ============================================================================
describe('sp-auth-wrapper.sh validation', () => {
  const content = readScript('sp-auth-wrapper.sh');

  it('calls sp-auth.js', () => {
    assert.match(content, /sp-auth\.js/, 'sp-auth-wrapper.sh should call sp-auth.js');
  });

  it('uses eval', () => {
    assert.match(content, /eval/, 'sp-auth-wrapper.sh should use eval');
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

  it('outputs SP_TOKEN in bash format', () => {
    assert.match(content, /SP_TOKEN/, 'sp-auth.js should output SP_TOKEN');
  });

  it('does not use any external OAuth client IDs', () => {
    assert.doesNotMatch(content, /04b07795-8ddb-461a-bbee-02f9e1bf7b46/,
      'sp-auth.js must not use Azure CLI client ID');
  });
});

// ============================================================================
// 11. sp-auth-wrapper.sh sets MSYS_NO_PATHCONV
// ============================================================================
describe('sp-auth-wrapper.sh MSYS fix', () => {
  const content = readScript('sp-auth-wrapper.sh');

  it('sets MSYS_NO_PATHCONV=1', () => {
    assert.match(content, /MSYS_NO_PATHCONV=1/, 'sp-auth-wrapper.sh should set MSYS_NO_PATHCONV=1');
  });

  it('sets it before the eval line', () => {
    const msysIdx = content.indexOf('MSYS_NO_PATHCONV');
    const evalIdx = content.indexOf('eval $(');
    assert.ok(msysIdx < evalIdx, 'MSYS_NO_PATHCONV should be set before eval');
  });
});

// ============================================================================
// 12. No external npm dependencies (require of local sp-env is OK)
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
