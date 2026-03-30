# SharePoint API Reference: File & Folder Operations

All file and folder operations available through the SharePoint REST API and Microsoft Graph API.

## Operations Covered

| Operation | Purpose | Primary API |
|-----------|---------|-------------|
| Read file | Read file content | SP REST / Graph |
| Create/upload file | Create or upload files | SP REST / Graph |
| Create folder | Create folders | SP REST |
| Rename item | Rename files or folders | SP REST (PATCH) |
| Move/copy items | Move or copy files | SP REST / Graph |
| List folder contents | List folder contents | SP REST / Graph |
| List document library files | List files in a document library | SP REST / Graph |
| Set folder color | Set folder color | SP REST |
| Share file | Share a file with a link | Graph |
| Delete items | Delete files or folders | SP REST |
| Search file content | Search within file content | Graph Search / SP Search |
| Get file versions | File version history | Graph |
| Restore file version | Restore a previous file version | Graph |
| Create Word document | Create a Word document from content | Graph |

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/web/getfilebyserverrelativeurl('{path}')               # File metadata
/_api/web/getfilebyserverrelativeurl('{path}')/$value        # File content (text)
/_api/web/getfilebyserverrelativeurl('{path}')/moveto(newurl='{dest}',flags=1)  # Move
/_api/web/getfolderbyserverrelativeurl('{path}')/Files       # Files in folder
/_api/web/getfolderbyserverrelativeurl('{path}')/Folders     # Subfolders
/_api/web/getfolderbyserverrelativeurl('{path}')/Files/add(url='{name}',overwrite=true)  # Upload
/_api/web/folders                                            # Create folder (POST)
/v1.0/drives/{driveId}/root/children                         # Root folder contents
/v1.0/drives/{driveId}/root:/{path}:/children                # Subfolder contents
/v1.0/drives/{driveId}/root:/{name}:/content                 # File content (GET/PUT)
/v1.0/drives/{driveId}/items/{itemId}                        # File metadata / delete
/v1.0/drives/{driveId}/items/{itemId}/content                # File content
/v1.0/drives/{driveId}/items/{itemId}/versions               # File versions
/v1.0/drives/{driveId}/items/{itemId}/createLink             # Share file (POST)
/v1.0/drives/{driveId}/items/{itemId}/copy                   # Copy file (POST)
```

---

## Reading Files

### Read file content by server-relative path (SP REST)

```bash
# Returns raw file content
node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```


### Read file content via Graph API

Graph supports text extraction from Word, Excel, and PDF files.

```bash
# Get raw file content
node scripts/graph-get.js "/v1.0/drives/{driveId}/items/{itemId}/content"

# Get file metadata (name, size, timestamps, etc.)
node scripts/graph-get.js "/v1.0/drives/{driveId}/items/{itemId}?\$select=name,size,lastModifiedDateTime,file"
```


### Key notes

- `/$value` returns the raw binary stream for SP REST.
- Graph `/content` returns the file bytes; the response `Content-Type` header indicates the MIME type.
- For large files, Graph supports range requests via the `Range` header.

---

## Uploading / Creating Files

### Create or overwrite a text file — small files (< 4 MB)

```bash
# SP REST — add file to a folder
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```


### Upload via Graph API (simple upload, < 4 MB)

```bash
# PUT to the file path under the parent folder
node scripts/graph-post.js \
  "/v1.0/drives/{driveId}/items/{parentId}:/{filename}:/content" \
  "File content here" \
  PUT
```


### Key notes

- For files > 4 MB, use a Graph upload session (`POST .../createUploadSession`).
- `overwrite=true` replaces an existing file; omit or set `false` to fail on conflict.
- Binary files must set the appropriate `Content-Type` header.

---

## Listing Folder Contents

### List subfolders (SP REST)

```bash
node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Folders"
```

### List files in a folder (SP REST)

```bash
node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files"
```

### List children via Graph (files and folders together)

```bash
node scripts/graph-get.js "/v1.0/drives/{driveId}/root/children?\$select=name,size,folder,file,lastModifiedDateTime"

# List children of a specific folder
node scripts/graph-get.js "/v1.0/drives/{driveId}/items/{folderId}/children?\$select=name,size,folder,file,lastModifiedDateTime"
```


### Key notes

- SP REST returns folders and files separately; Graph returns both in a single `children` call.
- Use `$top` and `$skipToken` for pagination.
- The `folder` property is present only on folders; `file` is present only on files — use this to distinguish.

---

## Creating Folders

### Create a folder (SP REST)

```bash
node scripts/sp-post.js "/_api/web/folders" \
  '{"ServerRelativeUrl":"/sites/mysite/Shared Documents/NewFolder"}'
```


### Create a folder via Graph

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{parentId}/children" \
  '{"name":"NewFolder","folder":{},"@microsoft.graph.conflictBehavior":"fail"}'
```

### Key notes

- SP REST creates the full path; intermediate folders must already exist.
- Graph `conflictBehavior` can be `fail`, `replace`, or `rename`.

---

## Renaming Items

### Rename a file (SP REST — PATCH)

```bash
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/old.txt')" \
  '{"Name":"new.txt"}' \
  PATCH
```

### Rename a folder (SP REST — PATCH)

```bash
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents/OldFolder')" \
  '{"Name":"NewFolder"}' \
  PATCH
```

### Rename via Graph

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}" \
  '{"name":"new-name.txt"}' \
  PATCH
```


---

## Moving / Copying Files

### Move a file (SP REST)

```bash
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/moveto(newurl='/sites/mysite/Archive/doc.txt',flags=1)" \
  ''
```

**Flags:** `1` = overwrite if exists, `0` = fail on conflict.

### Copy a file (SP REST)

```bash
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/copyto(strnewurl='/sites/mysite/Archive/doc.txt',boverwrite=true)" \
  ''
```

### Copy via Graph API

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}/copy" \
  '{"parentReference":{"driveId":"{destDriveId}","id":"{destFolderId}"},"name":"doc.txt"}'
```


### Move via Graph API

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}" \
  '{"parentReference":{"id":"{destFolderId}"}}' \
  PATCH
```

### Key notes

- Graph copy is asynchronous — returns a `Location` header with a monitor URL.
- Graph move is a PATCH that changes the `parentReference`.
- Cross-site moves require Graph; SP REST `moveto` works within the same site collection.

---

## Deleting Files

### Delete to recycle bin (SP REST)

```bash
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/recycle" \
  ''
```

### Permanent delete (SP REST)

```bash
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')" \
  '' \
  DELETE
```

### Delete via Graph

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}" '' DELETE
```


### Key notes

- Prefer `recycle` over `DELETE` — recycle bin allows recovery.
- Graph `DELETE` sends items to the recycle bin by default.

---

## Setting Folder Color

### Set folder color (SP REST)

```bash
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents/MyFolder')/ListItemAllFields" \
  '{"_ColorHex":"#038387"}' \
  PATCH
```

### Supported color values

| Color | Hex |
|-------|-----|
| Dark red | `#A4262C` |
| Red | `#D13438` |
| Orange | `#CA5010` |
| Yellow | `#C19C00` |
| Green | `#498205` |
| Teal | `#038387` |
| Blue | `#0078D4` |
| Purple | `#8764B8` |
| Pink | `#E3008C` |

Set to empty string (`""`) to remove the color.

---

## Sharing Files

### Create a sharing link (Graph API)

```bash
# Organization-wide view link
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}/createLink" \
  '{"type":"view","scope":"organization"}'

# Anyone link with edit permissions
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}/createLink" \
  '{"type":"edit","scope":"anonymous"}'
```


### Link types and scopes

| `type` | Permission |
|--------|------------|
| `view` | Read-only |
| `edit` | Read-write |
| `embed` | Embeddable read-only |

| `scope` | Audience |
|---------|----------|
| `anonymous` | Anyone with the link |
| `organization` | Anyone in the tenant |
| `users` | Specific people (requires `recipients`) |

---

## File Version History

### Get version history (Graph API)

```bash
node scripts/graph-get.js "/v1.0/drives/{driveId}/items/{itemId}/versions"
```


### Get a specific version's content

```bash
node scripts/graph-get.js "/v1.0/drives/{driveId}/items/{itemId}/versions/{versionId}/content"
```

### Restore a version

```bash
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}/versions/{versionId}/restoreVersion" ''
```


---

## Searching File Content

### Graph Search API (KQL)

```bash
node scripts/graph-post.js "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["driveItem"],
    "query": { "queryString": "content search term" },
    "from": 0,
    "size": 25
  }]
}'
```

### SP Search API

```bash
node scripts/sp-get.js "/_api/search/query?querytext='content search term'&selectproperties='Title,Path,Author,Size'"
```


### Key notes

- Graph Search uses KQL (Keyword Query Language) — supports `AND`, `OR`, `NOT`, property filters.
- SP Search returns managed properties; Graph Search returns `driveItem` resources.
- Both support searching inside file content (Word, PDF, etc.) via full-text indexing.

---

## Creating Word Documents

### Create an empty Word document, then upload content (Graph)

```bash
# Step 1: Create empty .docx in target folder
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{parentId}/children" \
  '{"name":"report.docx","file":{},"@microsoft.graph.conflictBehavior":"rename"}'

# Step 2: Upload content to the created file
node scripts/graph-post.js "/v1.0/drives/{driveId}/items/{itemId}/content" \
  "<binary-docx-content>" \
  PUT
```

### Key notes

- Creating a `.docx` with Graph requires uploading valid Office Open XML content.
- For plain text or markdown conversion, generate the `.docx` binary first (e.g., using a library) and then upload via Graph.
- Creating a Word document with formatted content requires generating valid Office Open XML before uploading.

---

## Common Patterns

### Error handling

All SP REST calls may return:
- `404` — file or folder not found
- `403` — insufficient permissions
- `409` — conflict (file locked, name collision with `overwrite=false`)
- `423` — file is locked (checked out by another user)

### File path encoding

- SP REST: server-relative URLs must be URL-encoded (spaces → `%20`).
- Graph: file names in paths use `:/{name}:/` syntax; URL-encode special characters.

### Large file handling

| Method | Size Limit |
|--------|-----------|
| SP REST `Files/add` | < 4 MB (250 MB with `$batch`) |
| Graph simple upload | < 4 MB |
| Graph upload session | Up to 250 GB |
