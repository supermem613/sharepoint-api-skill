# SharePoint API Reference: File & Folder Operations

All file and folder operations available through the SharePoint REST API.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Read file | Read file content |
| Create/upload file | Create or upload files |
| Create folder | Create folders |
| Rename item | Rename files or folders |
| Move/copy items | Move or copy files |
| List folder contents | List folder contents |
| List document library files | List files in a document library |
| Set folder color | Set folder color |
| Delete items | Delete files or folders |
| Search file content | Search within file content |
| Get file versions | File version history |

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/web/getfilebyserverrelativeurl('{path}')               # File metadata
/_api/web/getfilebyserverrelativeurl('{path}')/$value        # File content (text)
/_api/web/getfilebyserverrelativeurl('{path}')/moveto(newurl='{dest}',flags=1)  # Move
/_api/web/getfolderbyserverrelativeurl('{path}')/Files       # Files in folder
/_api/web/getfolderbyserverrelativeurl('{path}')/Folders     # Subfolders
/_api/web/getfolderbyserverrelativeurl('{path}')/Files/add(url='{name}',overwrite=true)  # Upload
/_api/web/getfolderbyserverrelativeurl('{parentPath}')/folders/add('{folderName}')  # Create folder
```

---

## Reading Files

### Read file content by server-relative path (SP REST)

```
# Returns raw file content
node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/\$value"
```


### Key notes

- `/$value` returns the raw binary stream for SP REST.

---

## Uploading / Creating Files

### Create or overwrite a text file — small files (< 4 MB)

```
# SP REST — add file to a folder
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files/add(url='newfile.txt',overwrite=true)" \
  "File content here"
```


### Key notes

- `overwrite=true` replaces an existing file; omit or set `false` to fail on conflict.
- Binary files must set the appropriate `Content-Type` header.
- For files > 4 MB, consider chunked upload approaches.

---

## Listing Folder Contents

### List subfolders (SP REST)

```
node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Folders"
```

### List files in a folder (SP REST)

```
node scripts/sp-get.js "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/Files"
```

### Key notes

- SP REST returns folders and files separately; use separate calls for `/Files` and `/Folders`.
- Use `$top` and `$skipToken` for pagination.

---

## Creating Folders

### Create a folder (SP REST)

```
# Create a folder inside an existing folder using folders/add
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents')/folders/add('NewFolder')" \
  ''
```

> **Note:** `POST /_api/web/folders` with a `{"ServerRelativeUrl":"..."}` body does **not** work in SharePoint Online REST. Use the `folders/add('FolderName')` method on the parent folder instead.

### Key notes

- SP REST `folders/add` creates a single folder; intermediate folders must already exist.

---

## Renaming Items

### Rename a file (SP REST — PATCH)

```
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/old.txt')" \
  '{"Name":"new.txt"}' \
  PATCH
```

### Rename a folder (SP REST — PATCH)

```
node scripts/sp-post.js \
  "/_api/web/getfolderbyserverrelativeurl('/sites/mysite/Shared Documents/OldFolder')" \
  '{"Name":"NewFolder"}' \
  PATCH
```

---

## Moving / Copying Files

### Move a file (SP REST)

```
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/moveto(newurl='/sites/mysite/Archive/doc.txt',flags=1)" \
  ''
```

**Flags:** `1` = overwrite if exists, `0` = fail on conflict.

### Copy a file (SP REST)

```
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/copyto(strnewurl='/sites/mysite/Archive/doc.txt',boverwrite=true)" \
  ''
```

### Key notes

- Cross-site moves within the same site collection use `moveto`; cross-site collection moves require manual download + re-upload.

---

## Deleting Files

### Delete to recycle bin (SP REST)

```
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')/recycle" \
  ''
```

### Permanent delete (SP REST)

```
node scripts/sp-post.js \
  "/_api/web/getfilebyserverrelativeurl('/sites/mysite/Shared Documents/doc.txt')" \
  '' \
  DELETE
```

### Key notes

- Prefer `recycle` over `DELETE` — recycle bin allows recovery.

---

## Setting Folder Color

### Set folder color (SP REST)

```
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

## File Version History

### Get version history (SP REST)

```
# File versions via SP REST (works with browser cookies)
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/items({itemId})/versions"
```

---

## Searching File Content

### SP Search API

```
node scripts/sp-get.js "/_api/search/query?querytext='content search term'&selectproperties='Title,Path,Author,Size'"
```


### Key notes

- SP Search returns managed properties.
- SP Search supports searching inside file content (Word, PDF, etc.) via full-text indexing.

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

### Large file handling

| Method | Size Limit |
|--------|-----------|
| SP REST `Files/add` | < 4 MB (250 MB with `$batch`) |
