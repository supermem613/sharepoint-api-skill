#!/usr/bin/env node
// Integration tests — requires authenticated SharePoint session
// Run: node --test tests/test-integration.js
// Prereq: source sp-auth-wrapper.sh first (sets SP_COOKIES + SP_SITE)

const { describe, it, after } = require('node:test');
const assert = require('node:assert');
const { execSync } = require('node:child_process');
const { join } = require('node:path');

const scriptsDir = join(__dirname, '..', '.claude', 'skills', 'sharepoint-api', 'scripts');

const SP_COOKIES = process.env.SP_COOKIES;
const SP_TOKEN = process.env.SP_TOKEN;
const SP_SITE = process.env.SP_SITE;

if (!SP_SITE || (!SP_COOKIES && !SP_TOKEN)) {
  console.log('⏭️  Skipping integration tests — not authenticated.');
  console.log('   Run: source scripts/sp-auth-wrapper.sh <tenant>');
  process.exit(0);
}

const TEST_PREFIX = `SPSKILL_TEST_${Date.now()}`;

// ============================================================================
// Helpers
// ============================================================================

function spGet(endpoint) {
  const stdout = execSync(`node "${join(scriptsDir, 'sp-get.js')}" "${endpoint}"`, {
    encoding: 'utf8', timeout: 30000, stdio: ['pipe', 'pipe', 'pipe']
  });
  return stdout;
}

function spGetJson(endpoint) {
  return JSON.parse(spGet(endpoint));
}

function spPost(endpoint, body, method) {
  const args = [`"${join(scriptsDir, 'sp-post.js')}"`, `"${endpoint}"`, `"${body.replace(/"/g, '\\"')}"`];
  if (method) args.push(`"${method}"`);
  const stdout = execSync(`node ${args.join(' ')}`, {
    encoding: 'utf8', timeout: 30000, stdio: ['pipe', 'pipe', 'pipe']
  });
  return stdout.trim() ? JSON.parse(stdout) : null;
}

// ============================================================================
// Connectivity check
// ============================================================================
console.log(`\n🔌 Checking connectivity to ${SP_SITE} ...`);
let webInfo;
try {
  webInfo = spGetJson('/_api/web?$select=Title,Url');
  console.log(`   Connected to: ${webInfo.Title} (${webInfo.Url})`);
} catch (e) {
  console.error('❌ Cannot reach SP site. Check SP_SITE and auth tokens.');
  process.exit(1);
}

const siteRelative = new URL(webInfo.Url).pathname;
const docLibRelative = `${siteRelative}/Shared Documents`;

console.log('\n═══════════════════════════════════════════');
console.log(' SharePoint API Skill — Integration Tests');
console.log(` Prefix: ${TEST_PREFIX}`);
console.log('═══════════════════════════════════════════\n');

// ============================================================================
// Site Info
// ============================================================================
describe('Site Info', () => {
  it('Get web info — Title and Url present', () => {
    const web = spGetJson('/_api/web?$select=Title,Url');
    assert.ok(web.Title, 'Missing Title');
    assert.ok(web.Url, 'Missing Url');
  });

  it('Get current user — Title and Email present', () => {
    const user = spGetJson('/_api/web/currentuser?$select=Title,Email');
    assert.ok(user.Title, 'Missing Title');
    assert.ok(user.Email, 'Missing Email');
  });
});

// ============================================================================
// List Discovery
// ============================================================================
describe('List Discovery', () => {
  it('Get all lists — response has value array with items', () => {
    const lists = spGetJson("/_api/web/lists?$filter=Hidden eq false&$select=Id,Title,ItemCount,BaseTemplate");
    assert.ok(Array.isArray(lists.value), 'No value array in response');
    assert.ok(lists.value.length > 0, 'value array is empty');
  });

  it('Each list has Title, Id, ItemCount fields', () => {
    const lists = spGetJson("/_api/web/lists?$filter=Hidden eq false&$select=Id,Title,ItemCount,BaseTemplate");
    for (const list of lists.value) {
      assert.ok(list.Title, 'List missing Title');
      assert.ok(list.Id, 'List missing Id');
      assert.ok(list.ItemCount !== undefined, `List '${list.Title}' missing ItemCount`);
    }
  });
});

// ============================================================================
// List Item CRUD
// ============================================================================
describe('List Item CRUD', () => {
  const testListTitle = `${TEST_PREFIX}_List`;
  let testListId = null;
  let testItemId = null;
  let entityType = null;
  const testItemTitle = `${TEST_PREFIX}_Item`;
  const testItemTitleUpdated = `${TEST_PREFIX}_Updated`;

  // Create a temporary list before CRUD tests
  let listCreated = false;
  try {
    const createBody = JSON.stringify({
      __metadata: { type: 'SP.List' },
      AllowContentTypes: true,
      BaseTemplate: 100,
      ContentTypesEnabled: true,
      Description: 'Temporary integration test list',
      Title: testListTitle
    });
    const newList = spPost('/_api/web/lists', createBody);
    testListId = newList?.d?.Id;
    listCreated = !!testListId;
    if (listCreated) {
      console.log(`   (Created temp list: ${testListTitle})`);
      const listMeta = spGetJson(`/_api/web/lists(guid'${testListId}')?$select=ListItemEntityTypeFullName`);
      entityType = listMeta.ListItemEntityTypeFullName;
    }
  } catch {
    console.log('   ⚠️  Failed to create temp list — CRUD tests will be skipped');
  }

  after(() => {
    if (testListId) {
      try {
        spPost(`/_api/web/lists(guid'${testListId}')`, '', 'DELETE');
        console.log(`   (Deleted temp list: ${testListTitle})`);
      } catch {
        console.log(`   ⚠️  Failed to clean up test list '${testListTitle}'. Delete it manually.`);
      }
    }
  });

  it('Create a list item — 200/201 response', { skip: !listCreated && 'No temp list' }, () => {
    const body = JSON.stringify({ __metadata: { type: entityType }, Title: testItemTitle });
    const created = spPost(`/_api/web/lists(guid'${testListId}')/items`, body);
    testItemId = created?.d?.Id;
    assert.ok(testItemId, 'No item Id returned');
  });

  it('Read item back — title matches', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped — no item created');
    const item = spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})?$select=Title,Id`);
    assert.strictEqual(item.Title, testItemTitle, `Title mismatch: expected '${testItemTitle}', got '${item.Title}'`);
  });

  it('Update the item — success', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped — no item created');
    const body = JSON.stringify({ __metadata: { type: entityType }, Title: testItemTitleUpdated });
    spPost(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`, body, 'PATCH');
  });

  it('Read updated item — new title matches', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped — no item created');
    const item = spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})?$select=Title`);
    assert.strictEqual(item.Title, testItemTitleUpdated);
  });

  it('Delete the item — success (204 or 200)', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped — no item created');
    spPost(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`, '', 'DELETE');
  });

  it('Verify item is gone (404)', { skip: !listCreated && 'No temp list' }, () => {
    assert.ok(testItemId, 'Skipped — no item created');
    assert.throws(
      () => spGetJson(`/_api/web/lists(guid'${testListId}')/items(${testItemId})`),
      'Expected 404 but item still exists'
    );
  });
});

// ============================================================================
// File Operations
// ============================================================================
describe('File Operations', () => {
  const testFileName = `${TEST_PREFIX}_testfile.txt`;
  const testFileContent = `Integration test content — ${TEST_PREFIX}`;
  let uploaded = false;

  after(() => {
    try {
      spPost(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${testFileName}')`, '', 'DELETE');
      console.log(`   (Deleted test file: ${testFileName})`);
    } catch {
      console.log(`   ⚠️  Failed to clean up test file '${testFileName}'. Delete it manually.`);
    }
  });

  it('List files in document library — response OK', () => {
    const files = spGetJson(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/files?$select=Name,Length&$top=10`);
    assert.ok(Array.isArray(files.value), "No 'value' array in response");
  });

  it('Upload a test file — success', () => {
    const encodedName = encodeURIComponent(testFileName);
    spPost(`/_api/web/getfolderbyserverrelativeurl('${docLibRelative}')/Files/add(url='${encodedName}',overwrite=true)`, testFileContent);
    uploaded = true;
  });

  it('Read file content back — matches', { skip: !uploaded && 'File not uploaded' }, () => {
    const content = spGet(`/_api/web/getfilebyserverrelativeurl('${docLibRelative}/${testFileName}')/$value`);
    assert.ok(content.includes(TEST_PREFIX), `Content mismatch — expected to contain '${TEST_PREFIX}'`);
  });
});
