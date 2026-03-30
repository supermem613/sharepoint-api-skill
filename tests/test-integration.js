#!/usr/bin/env node
// Integration tests — requires authenticated SharePoint session
//
// Usage:
//   npm run test:integration                          # Uses cached auth from ~/.sharepoint-api-skill/auth.json
//   npm run test:integration -- <site-url>            # Auto-authenticates to the site first
//   node --test tests/test-integration.js <site-url>  # Same
//

const { describe, it, after } = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const { join } = require('node:path');
const fs = require('node:fs');
const os = require('node:os');

const scriptsDir = join(__dirname, '..', '.claude', 'skills', 'sharepoint-api', 'scripts');
const AUTH_FILE = join(os.homedir(), '.sharepoint-api-skill', 'auth.json');

// Determine which site to authenticate to
const siteArg = process.argv.find(a => a.includes('sharepoint') && a.includes('.com') && !a.startsWith('-'));

// Load existing auth file to get the site URL if no arg
let cachedSite = '';
try { cachedSite = JSON.parse(fs.readFileSync(AUTH_FILE, 'utf8')).SP_SITE || ''; } catch {}

const targetSite = siteArg || cachedSite;
if (!targetSite) {
  console.log('Skipping integration tests — no site URL available.');
  console.log('');
  console.log('  Option 1: Pass the site URL directly:');
  console.log('    npm run test:integration -- contoso.sharepoint.com/sites/mysite');
  console.log('');
  console.log('  Option 2: Authenticate first, then run:');
  console.log('    source scripts/sp-auth-wrapper.sh contoso.sharepoint.com/sites/mysite');
  console.log('    npm run test:integration');
  process.exit(1);
}

// ALWAYS re-authenticate to get fresh cookies
console.log(`\u{1f511} Authenticating to ${targetSite}...`);
try {
  const authScript = join(scriptsDir, 'sp-auth.js');
  const siteForAuth = targetSite.replace(/^https?:\/\//, '');
  execFileSync('node', [authScript, siteForAuth], {
    timeout: 120000, stdio: ['pipe', 'pipe', 'inherit']  // stderr to console (login prompts), stdout suppressed (contains cookies)
  });
} catch (e) {
  console.error('Authentication failed');
  process.exit(1);
}

// Load the fresh auth from auth.json
const auth = JSON.parse(fs.readFileSync(AUTH_FILE, 'utf8'));
process.env.SP_SITE = auth.SP_SITE;
process.env.SP_COOKIES = auth.SP_COOKIES || '';
if (auth.SP_TOKEN) process.env.SP_TOKEN = auth.SP_TOKEN;
console.log(`   SP_SITE: ${auth.SP_SITE}`);
console.log(`   SP_COOKIES: ${auth.SP_COOKIES ? 'set' : 'empty'}`);
console.log(`   SP_TOKEN: ${auth.SP_TOKEN ? 'set' : 'empty'}`);

const TEST_PREFIX = `SHAREPOINT_API_SKILL_TEST_${Date.now()}`;

// ============================================================================
// Helpers
// ============================================================================

function spGet(endpoint) {
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      return execFileSync('node', [join(scriptsDir, 'sp-get.js'), endpoint], {
        encoding: 'utf8', timeout: 60000, stdio: ['pipe', 'pipe', 'pipe']
      });
    } catch (e) {
      if (attempt === 2 || !e.message?.includes('fetch failed')) throw e;
      sleep(2000); // retry once on transient network error
    }
  }
}

function spGetJson(endpoint) {
  return JSON.parse(spGet(endpoint));
}

function spPost(endpoint, body, method) {
  const args = [join(scriptsDir, 'sp-post.js'), endpoint, body];
  if (method) args.push(method);
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const stdout = execFileSync('node', args, {
        encoding: 'utf8', timeout: 60000, stdio: ['pipe', 'pipe', 'pipe']
      });
      if (!stdout.trim()) return null;
      try {
        const parsed = JSON.parse(stdout);
        return parsed.d || parsed;
      } catch {
        try { return JSON.parse(JSON.parse(stdout)); } catch {}
        return null;
      }
    } catch (e) {
      if (attempt === 2 || !e.message?.includes('fetch failed')) throw e;
      sleep(2000);
    }
  }
}

/** Attempt a DELETE and swallow errors — used in after() cleanup */
function safeDelete(endpoint) {
  try { spPost(endpoint, '', 'DELETE'); } catch {}
}

// ============================================================================
// Connectivity check  (eval 01)
// ============================================================================
console.log(`\n\ud83d\udd0c Checking connectivity to ${auth.SP_SITE} ...`);
let webInfo;
try {
  webInfo = spGetJson('/_api/web?$select=Title,Url');
  console.log(`   Connected to: ${webInfo.Title} (${webInfo.Url})`);
} catch (e) {
  console.error('\u274c Cannot reach SP site. Check SP_SITE and auth tokens.');
  process.exit(1);
}

/** Synchronous sleep — blocks the process for the given milliseconds */
function sleep(ms) {
  execFileSync('node', ['-e', `Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,${ms})`], { timeout: ms + 2000 });
}

// ============================================================================
// Shared temp list (reused by CRUD, columns, views, formatting, versions)
// ============================================================================
const testListTitle = `${TEST_PREFIX}_List`;
let testListId = null;
let entityType = null;
let listCreated = false;

try {
  const createBody = JSON.stringify({
    __metadata: { type: 'SP.List' },
    AllowContentTypes: true,
    BaseTemplate: 100,
    ContentTypesEnabled: true,
    EnableVersioning: true,
    Description: 'Temporary integration test list',
    Title: testListTitle
  });
  const newList = spPost('/_api/web/lists', createBody);
  testListId = newList?.Id;
  listCreated = !!testListId;
  if (listCreated) {
    console.log(`   (Created temp list: ${testListTitle})`);
    const listMeta = spGetJson(`/_api/web/lists(guid'${testListId}')?$select=ListItemEntityTypeFullName`);
    entityType = listMeta.ListItemEntityTypeFullName;
  }
} catch {
  console.log('   \u26a0\ufe0f  Failed to create temp list \u2014 list-dependent tests will be skipped');
}

// ============================================================================
// Shared temp doc lib (reused by file, folder, and move tests)
// ============================================================================
const docLibTitle = `${TEST_PREFIX}_DocLib`;
let docLibId = null;
let docLibRelative = null;
let docLibCreated = false;

try {
  const createDocLibBody = JSON.stringify({
    __metadata: { type: 'SP.List' },
    BaseTemplate: 101,  // Document Library
    Title: docLibTitle,
    Description: 'Temporary integration test document library'
  });
  const newLib = spPost('/_api/web/lists', createDocLibBody);
  docLibId = newLib?.Id;
  docLibCreated = !!docLibId;
  if (docLibCreated) {
    console.log(`   (Created temp doc lib: ${docLibTitle})`);
    const libInfo = spGetJson(`/_api/web/lists(guid'${docLibId}')/rootfolder?$select=ServerRelativeUrl`);
    docLibRelative = libInfo.ServerRelativeUrl;
  }
} catch {
  console.log('   \u26a0\ufe0f  Failed to create temp doc lib \u2014 file-dependent tests will be skipped');
}

// Top-level cleanup: delete shared temp list and doc lib after all tests
after(() => {
  if (testListId) {
    try {
      spPost(`/_api/web/lists(guid'${testListId}')`, '', 'DELETE');
      console.log(`   (Deleted temp list: ${testListTitle})`);
    } catch {
      console.log(`   \u26a0\ufe0f  Failed to clean up test list '${testListTitle}'. Delete it manually.`);
    }
  }
  if (docLibId) {
    try {
      spPost(`/_api/web/lists(guid'${docLibId}')`, '', 'DELETE');
      console.log(`   (Deleted temp doc lib: ${docLibTitle})`);
    } catch {
      console.log(`   \u26a0\ufe0f  Failed to clean up test doc lib '${docLibTitle}'. Delete it manually.`);
    }
  }
});

console.log('\n\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550');
console.log(' SharePoint API Skill \u2014 Integration Tests');
console.log(` Prefix: ${TEST_PREFIX}`);
console.log('\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\n');

// ============================================================================
// Site Info  (evals 01, 04)
// ============================================================================
describe('Site Info', () => {
  it('01/04 \u2014 Get web info \u2014 Title and Url present', () => {
    const web = spGetJson('/_api/web?$select=Title,Url,Description');
    assert.ok(web.Title, 'Missing Title');
    assert.ok(web.Url, 'Missing Url');
  });

  it('Get current user \u2014 Title and Email present', () => {
    const user = spGetJson('/_api/web/currentuser?$select=Title,Email');
    assert.ok(user.Title, 'Missing Title');
    assert.ok(user.Email, 'Missing Email');
  });
});

// ============================================================================
// Discovery  (evals 02, 03, 47, 48)
// ============================================================================
describe('Discovery', () => {
  // Probe taxonomy availability
  let taxonomyAvailable = false;
  try {
    spGetJson('/_api/v2.1/termstore');
    taxonomyAvailable = true;
  } catch {}

  it('02 \u2014 Discover lists \u2014 value array with items', () => {
    const lists = spGetJson("/_api/web/lists?$filter=Hidden eq false&$select=Id,Title,ItemCount,BaseTemplate");
    assert.ok(Array.isArray(lists.value), 'No value array in response');
    assert.ok(lists.value.length > 0, 'value array is empty');
    for (const list of lists.value) {
      assert.ok(list.Title, 'List missing Title');
      assert.ok(list.Id, 'List missing Id');
      assert.ok(list.ItemCount !== undefined, `List '${list.Title}' missing ItemCount`);
    }
  });

  it('03 \u2014 Get list schema \u2014 fields have TypeAsString', { skip: !listCreated && 'No temp list' }, () => {
    const fields = spGetJson(`/_api/web/lists(guid'${testListId}')/fields?$filter=Hidden eq false&$select=Title,InternalName,TypeAsString`);
    assert.ok(Array.isArray(fields.value), 'No value array');
    assert.ok(fields.value.length > 0, 'No visible fields');
    assert.ok(fields.value[0].TypeAsString, 'Missing TypeAsString');
  });

  it('47 \u2014 Taxonomy termstore', { skip: !taxonomyAvailable && 'Termstore endpoint not available' }, () => {
    const ts = spGetJson('/_api/v2.1/termstore');
    assert.ok(ts, 'Empty termstore response');
  });

  it('48 \u2014 Content types on list', { skip: !listCreated && 'No temp list' }, () => {
    const ct = spGetJson(`/_api/web/lists(guid'${testListId}')/contenttypes?$select=Name,Id`);
    assert.ok(Array.isArray(ct.value), 'No value array');
    assert.ok(ct.value.length > 0, 'No content types');
    assert.ok(ct.value[0].Name, 'Missing Name on content type');
  });
});

// ============================================================================
// List Item CRUD  (evals 05, 06, 07, 08, 09, 20, 28)
// ============================================================================
describe('List Item CRUD', () => {
  let testItemId = null;
  const testItemTitle = `${TEST_PREFIX}_Item`;
  const testItemTitleUpdated = `${TEST_PREFIX}_Updated`;

  it('06 \u2014 Create a list item', { skip: !listCreated && 'No temp list' }, () => {
    const body = JSON.stringify({ __metadata: { type: entityType }, Title: testItemTitle });
    const created = spPost(`/_api/web/lists(guid'${testListId}')/items`, body);
    testItemId = created?.Id;
    assert.ok(testItemId, 'No item Id returned');
  });

  it('Read item back \u2014 title matches', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    const item = spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})?$select=Title,Id`);
    assert.strictEqual(item.Title, testItemTitle, `Title mismatch: expected '${testItemTitle}', got '${item.Title}'`);
  });

  it('07 \u2014 Update the item', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    const body = JSON.stringify({ __metadata: { type: entityType }, Title: testItemTitleUpdated });
    spPost(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`, body, 'PATCH');
  });

  it('Read updated item \u2014 new title matches', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    const item = spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})?$select=Title`);
    assert.strictEqual(item.Title, testItemTitleUpdated);
  });

  it('05 \u2014 Read items from list', { skip: !listCreated && 'No temp list' }, () => {
    const items = spGetJson(`/_api/web/lists(guid'${testListId}')/items?$select=Title,Id&$top=5`);
    assert.ok(Array.isArray(items.value), 'No value array');
    assert.ok(items.value.length > 0, 'No items found');
  });

  it('09 \u2014 Filter items', { skip: !listCreated && 'No temp list' }, () => {
    const items = spGetJson(`/_api/web/lists(guid'${testListId}')/items?$filter=Id gt 0&$select=Title,Id&$top=3`);
    assert.ok(Array.isArray(items.value), 'No value array');
    assert.ok(items.value.length > 0, 'Filter returned no items');
  });

  it('20 \u2014 CAML query via GetItems', { skip: !listCreated && 'No temp list' }, () => {
    // Create a dedicated item for the CAML query
    const camlItemBody = JSON.stringify({ __metadata: { type: entityType }, Title: `${TEST_PREFIX}_CAML` });
    const camlItem = spPost(`/_api/web/lists(guid'${testListId}')/items`, camlItemBody);
    try {
      const camlBody = JSON.stringify({
        query: {
          __metadata: { type: 'SP.CamlQuery' },
          ViewXml: '<View><Query><Where><Gt><FieldRef Name="Id" /><Value Type="Integer">0</Value></Gt></Where></Query><RowLimit>3</RowLimit></View>'
        }
      });
      const result = spPost(`/_api/web/lists(guid'${testListId}')/GetItems`, camlBody);
      assert.ok(result, 'Empty CAML response');
    } catch (e) {
      // Some environments return 500 "field types not installed" on freshly created lists
      if (e.message && e.message.includes('field types are not installed')) {
        console.log('   (CAML skipped \u2014 field type issue on this environment)');
        return;
      }
      throw e;
    } finally {
      if (camlItem?.Id) safeDelete(`/_api/web/lists(guid'${testListId}')/items(${camlItem.Id})`);
    }
  });

  it('28 \u2014 Item version history', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    const versions = spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})/versions?$select=VersionLabel`);
    assert.ok(Array.isArray(versions.value), 'No value array');
    assert.ok(versions.value.length >= 1, 'Expected at least 1 version');
    assert.ok(versions.value[0].VersionLabel, 'Missing VersionLabel');
  });

  it('08 \u2014 Delete the item', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    spPost(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`, '', 'DELETE');
  });

  it('Verify item is gone (404)', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped \u2014 no item created');
    assert.throws(
      () => spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`),
      'Expected 404 but item still exists'
    );
  });
});

// ============================================================================
// List Columns  (evals 21, 22)
// ============================================================================
describe('List Columns', () => {
  const colName = `${TEST_PREFIX}_Column`;
  let columnCreated = false;

  after(() => {
    if (columnCreated) {
      safeDelete(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('${colName}')`);
    }
  });

  it('21 \u2014 Add column', { skip: !listCreated && 'No temp list' }, () => {
    const body = JSON.stringify({
      __metadata: { type: 'SP.Field' },
      Title: colName,
      FieldTypeKind: 2
    });
    const result = spPost(`/_api/web/lists(guid'${testListId}')/fields`, body);
    assert.ok(result, 'No response from add column');
    columnCreated = true;
  });

  it('Verify column exists', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(columnCreated, 'Skipped \u2014 column not created');
    const field = spGetJson(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('${colName}')?$select=Title,InternalName`);
    assert.strictEqual(field.Title, colName);
  });

  it('22 \u2014 Delete column', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(columnCreated, 'Skipped \u2014 column not created');
    spPost(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('${colName}')`, '', 'DELETE');
    columnCreated = false;
  });
});

// ============================================================================
// List Views  (evals 19, 23, 24, 25)
// ============================================================================
describe('List Views', () => {
  const viewName = `${TEST_PREFIX}_View`;
  const viewNameUpdated = `${TEST_PREFIX}_View_Updated`;
  let viewId = null;

  after(() => {
    if (viewId) {
      safeDelete(`/_api/web/lists(guid'${testListId}')/views(guid'${viewId}')`);
    }
  });

  it('19 \u2014 List views for the temp list', { skip: !listCreated && 'No temp list' }, () => {
    const views = spGetJson(`/_api/web/lists(guid'${testListId}')/views?$select=Title,Id,ServerRelativeUrl`);
    assert.ok(Array.isArray(views.value), 'No value array');
    assert.ok(views.value.length > 0, 'No views found (every list has at least one)');
  });

  it('23 \u2014 Create view', { skip: !listCreated && 'No temp list' }, () => {
    const body = JSON.stringify({
      __metadata: { type: 'SP.View' },
      Title: viewName,
      RowLimit: 10,
      PersonalView: false
    });
    const result = spPost(`/_api/web/lists(guid'${testListId}')/views`, body);
    viewId = result?.Id;
    assert.ok(viewId, 'No view Id returned');
  });

  it('24 \u2014 Update view', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(viewId, 'Skipped \u2014 no view created');
    const body = JSON.stringify({
      __metadata: { type: 'SP.View' },
      Title: viewNameUpdated,
      RowLimit: 5
    });
    spPost(`/_api/web/lists(guid'${testListId}')/views(guid'${viewId}')`, body, 'PATCH');
  });

  it('25 \u2014 Delete view', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(viewId, 'Skipped \u2014 no view created');
    spPost(`/_api/web/lists(guid'${testListId}')/views(guid'${viewId}')`, '', 'DELETE');
    viewId = null;
  });
});

// ============================================================================
// Column Formatting  (eval 29)
// ============================================================================
describe('Column Formatting', () => {
  let formattingApplied = false;

  after(() => {
    if (formattingApplied) {
      try {
        const revert = JSON.stringify({ __metadata: { type: 'SP.Field' }, CustomFormatter: null });
        spPost(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('Title')`, revert, 'PATCH');
      } catch {}
    }
  });

  it('29 \u2014 Apply column formatting and revert', { skip: !listCreated && 'No temp list' }, () => {
    const formatter = JSON.stringify({ elmType: 'div', txtContent: '@currentField' });
    const body = JSON.stringify({ __metadata: { type: 'SP.Field' }, CustomFormatter: formatter });
    spPost(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('Title')`, body, 'PATCH');
    formattingApplied = true;

    // Revert immediately
    const revert = JSON.stringify({ __metadata: { type: 'SP.Field' }, CustomFormatter: null });
    spPost(`/_api/web/lists(guid'${testListId}')/fields/getbytitle('Title')`, revert, 'PATCH');
    formattingApplied = false;
  });
});

// ============================================================================
// List Lifecycle  (evals 26, 27)
// ============================================================================
describe('List Lifecycle', () => {
  const lcListTitle = `${TEST_PREFIX}_Lifecycle`;
  let lcListId = null;

  after(() => {
    if (lcListId) {
      safeDelete(`/_api/web/lists(guid'${lcListId}')`);
    }
  });

  it('26 \u2014 Create list', () => {
    const body = JSON.stringify({
      __metadata: { type: 'SP.List' },
      Title: lcListTitle,
      BaseTemplate: 100
    });
    const result = spPost('/_api/web/lists', body);
    lcListId = result?.Id;
    assert.ok(lcListId, 'No list Id returned');
  });

  it('27 \u2014 Delete list', () => {
    assert.ok(lcListId, 'Skipped \u2014 no list created');
    spPost(`/_api/web/lists(guid'${lcListId}')`, '', 'DELETE');
    lcListId = null;
  });
});

// ============================================================================
// File Operations  (evals 10, 11, 12, 13)
// ============================================================================
describe('File Operations', () => {
  const testFileName = `${TEST_PREFIX}_testfile.txt`;
  const testFileContent = `Integration test content \u2014 ${TEST_PREFIX}`;
  let uploaded = false;
  let deleted = false;

  after(() => {
    if (uploaded && !deleted) {
      safeDelete(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${testFileName}')`);
    }
  });

  it('10 \u2014 List files in document library', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    const files = spGetJson(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/files?$select=Name,Length&$top=10`);
    assert.ok(Array.isArray(files.value), "No 'value' array in response");
  });

  it('12 \u2014 Upload a test file', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    const encodedName = encodeURIComponent(testFileName);
    spPost(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/Files/add(url='${encodedName}',overwrite=true)`, testFileContent);
    uploaded = true;
  });

  it('11 \u2014 Read file content back', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    if (!uploaded) { console.log('   (skipped \u2014 file not uploaded)'); return; }
    const content = spGet(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${testFileName}')/$value`);
    assert.ok(content.includes(TEST_PREFIX), `Content mismatch \u2014 expected to contain '${TEST_PREFIX}'`);
  });

  it('13 \u2014 Delete file', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    if (!uploaded) { console.log('   (skipped \u2014 file not uploaded)'); return; }
    spPost(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${testFileName}')`, '', 'DELETE');
    deleted = true;
  });
});

// ============================================================================
// Folder Operations  (evals 30, 31)
// ============================================================================
describe('Folder Operations', () => {
  const folderName = `${TEST_PREFIX}_Folder`;
  const renamedName = `${TEST_PREFIX}_Folder_Renamed`;
  let folderCreated = false;
  let folderRenamed = false;

  after(() => {
    if (folderRenamed) {
      safeDelete(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}/${renamedName}')`);
    }
    if (folderCreated) {
      safeDelete(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}/${folderName}')`);
    }
  });

  it('30 \u2014 Create folder', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    spPost(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/folders/add('${folderName}')`, '');
    folderCreated = true;
  });

  it('31 \u2014 Rename folder', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    if (!folderCreated) { console.log('   (skipped \u2014 folder not created)'); return; }
    const body = JSON.stringify({ __metadata: { type: 'SP.Folder' }, Name: renamedName });
    spPost(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}/${folderName}')`, body, 'PATCH');
    folderRenamed = true;
  });
});

// ============================================================================
// File Move  (eval 32)
// ============================================================================
describe('File Move', () => {
  const moveFileName = `${TEST_PREFIX}_moveme.txt`;
  const movedFileName = `${TEST_PREFIX}_moved.txt`;

  after(() => {
    safeDelete(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${movedFileName}')`);
    safeDelete(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${moveFileName}')`);
  });

  it('32 \u2014 Move file', { skip: !docLibCreated && 'No temp doc lib' }, () => {
    // Upload source file
    const encodedName = encodeURIComponent(moveFileName);
    spPost(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/Files/add(url='${encodedName}',overwrite=true)`, 'move test');

    // Move it
    spPost(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${moveFileName}')/moveto(newurl='${docLibRelative}/${movedFileName}',flags=1)`, '');

    // Verify moved file exists
    const content = spGet(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${movedFileName}')/$value`);
    assert.ok(content.includes('move test'), 'Moved file content mismatch');
  });
});

// ============================================================================
// Search  (eval 15)
// ============================================================================
describe('Search', () => {
  it('15 \u2014 SP REST search', () => {
    // Search for our test prefix \u2014 verifies the API call works.
    // Note: search indexing may take minutes, so we just verify the response structure.
    const result = spGetJson(`/_api/search/query?querytext='${TEST_PREFIX}'&rowlimit=1`);
    assert.ok(
      result.PrimaryQueryResult || result.ElapsedTime !== undefined,
      'Invalid search response structure'
    );
  });
});

// ============================================================================
// Users & Permissions  (evals 16, 17, 43)
// ============================================================================
describe('Users & Permissions', () => {
  it('16 \u2014 Current user \u2014 Id, Title, Email, LoginName', () => {
    const user = spGetJson('/_api/web/currentuser?$select=Title,Email,Id,LoginName');
    assert.ok(user.Id, 'Missing Id');
    assert.ok(user.Title, 'Missing Title');
    assert.ok(user.Email, 'Missing Email');
    assert.ok(user.LoginName, 'Missing LoginName');
  });

  it('17 \u2014 List site users', () => {
    const users = spGetJson('/_api/web/siteusers?$select=Title,Email,Id&$top=5');
    assert.ok(Array.isArray(users.value), 'No value array');
    assert.ok(users.value.length > 0, 'No users found');
  });

  it('43 \u2014 Role assignments (permissions)', () => {
    const raw = spGet('/_api/web/roleassignments?$expand=Member,RoleDefinitionBindings&$top=5');
    assert.ok(
      raw.includes('PrincipalId') || raw.includes('RoleDefinitionBindings'),
      'Missing PrincipalId or RoleDefinitionBindings'
    );
  });
});

// ============================================================================
// Pages  (evals 35, 36, 37, 38)
// ============================================================================
describe('Pages', () => {
  const pageTitle = `${TEST_PREFIX}_Page`;
  const pageTitleUpdated = `${TEST_PREFIX}_Page_Updated`;
  let pageId = null;

  after(() => {
    if (pageId) {
      safeDelete(`/_api/sitepages/pages(${pageId})`);
    }
  });

  it('36 \u2014 Create page and publish', () => {
    const body = JSON.stringify({
      __metadata: { type: 'SP.Publishing.SitePage' },
      Title: pageTitle,
      PageLayoutType: 'Article'
    });
    const result = spPost('/_api/sitepages/pages', body);
    pageId = result?.Id;
    assert.ok(pageId, 'No page Id returned');

    // Publish the page
    spPost(`/_api/sitepages/pages(${pageId})/publish`, '');
  });

  it('35 \u2014 List pages (verify test page appears)', () => {
    const pages = spGetJson('/_api/sitepages/pages?$select=Title,FileName,Id&$top=50');
    assert.ok(Array.isArray(pages.value), 'No value array');
    if (pageId) {
      const found = pages.value.some(p => p.Id === pageId);
      assert.ok(found, `Test page (Id=${pageId}) not found in pages list`);
    }
  });

  it('37 \u2014 Edit page', () => {
    assert.ok(pageId, 'Skipped \u2014 no page created');
    // Wait for SP to finalize the page
    sleep(3000);
    // Publish to close any lingering edit session
    try { spPost(`/_api/sitepages/pages(${pageId})/publish`, ''); } catch {}
    sleep(1000);
    // Edit via Site Pages list item (avoids 409 on sitepages endpoint)
    // Needs __metadata.type for odata=verbose and MERGE method
    try {
      const body = JSON.stringify({
        __metadata: { type: 'SP.Publishing.SitePage' },
        Title: pageTitleUpdated
      });
      spPost(`/_api/sitepages/pages(${pageId})`, body, 'PATCH');
    } catch (e) {
      if (e.message && e.message.includes('409')) {
        console.log('   (sitepages PATCH 409 \u2014 using list item fallback)');
        const listEntityType = spGetJson("/_api/web/lists/getbytitle('Site Pages')?$select=ListItemEntityTypeFullName").ListItemEntityTypeFullName;
        const body = JSON.stringify({ __metadata: { type: listEntityType }, Title: pageTitleUpdated });
        spPost(`/_api/web/lists/getbytitle('Site Pages')/items(${pageId})`, body, 'MERGE');
      } else {
        throw e;
      }
    }
  });

  it('38 \u2014 Delete page', () => {
    assert.ok(pageId, 'Skipped \u2014 no page created');
    spPost(`/_api/sitepages/pages(${pageId})`, '', 'DELETE');
    pageId = null;
  });
});

// ============================================================================
// Advanced  (evals 18, 39, 40, 41, 42)
// ============================================================================
describe('Advanced', () => {
  // Probe rules endpoint availability
  let rulesAvailable = false;
  if (listCreated) {
    try {
      spGetJson(`/_api/web/lists(guid'${testListId}')/SPListRules`);
      rulesAvailable = true;
    } catch {}
  }
  let ruleId = null;

  after(() => {
    if (ruleId) {
      safeDelete(`/_api/web/lists(guid'${testListId}')/SPListRules(${ruleId})`);
    }
  });

  it('18 \u2014 Recycle bin', () => {
    const bin = spGetJson('/_api/web/recyclebin?$top=5&$select=Title,ItemType,DeletedDate');
    assert.ok(Array.isArray(bin.value), 'No value array');
  });

  it('39 \u2014 Create rule', { skip: (!listCreated && 'No temp list') || (!rulesAvailable && 'SPListRules endpoint not available') }, () => {
    const body = JSON.stringify({
      Condition: '<condition/>',
      ActionType: 'Custom',
      ActionParams: '{"action":"noop"}',
      TriggerType: 'OnNewItem',
      Title: `${TEST_PREFIX}_Rule`
    });
    const result = spPost(`/_api/web/lists(guid'${testListId}')/SPListRules`, body);
    ruleId = result?.Id;
    assert.ok(ruleId, 'No rule Id returned');
  });

  it('40 \u2014 Delete rule', { skip: (!listCreated && 'No temp list') || (!rulesAvailable && 'SPListRules endpoint not available') }, () => {
    assert.ok(ruleId, 'Skipped \u2014 no rule created');
    spPost(`/_api/web/lists(guid'${testListId}')/SPListRules(${ruleId})`, '', 'DELETE');
    ruleId = null;
  });

  it('41 \u2014 Navigation (quicklaunch)', () => {
    const nav = spGetJson('/_api/web/navigation/quicklaunch?$select=Title,Url,Id');
    assert.ok(Array.isArray(nav.value), 'No value array');
  });

  it('42 \u2014 Site features', () => {
    const features = spGetJson('/_api/web/features?$select=DefinitionId,DisplayName');
    assert.ok(Array.isArray(features.value), 'No value array');
  });
});
