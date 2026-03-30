# SharePoint Search API Reference

> **Operations covered:** Site-scoped file search, list item search, content search, item filtering

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/search/query?querytext='{query}'                       # SP REST Search (GET) — works with cookies ✅
/_api/search/query?querytext='{query}'&selectproperties='Title,Path'&rowlimit=25
```

---

## SharePoint REST Search API

SP REST search works with browser cookies set by `sp-auth.js`. It requires no bearer token and is always available after authentication.

### Basic keyword search

```
node scripts/sp-get.js "/_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=25"
```

### Search within current site

```
node scripts/sp-get.js "/_api/search/query?querytext='budget report site:$SP_SITE'&selectproperties='Title,Path'"
```

### Search with refiners (facets)

```
node scripts/sp-get.js "/_api/search/query?querytext='*'&refinementfilters='FileType:equals(\"docx\")'&selectproperties='Title,Path,Size'"
```

---

## Additional SP REST Search Patterns

### Refiners (SP REST only)

Request refiners to get faceted counts, then apply refinement filters:

```
# Step 1 — request refiners
node scripts/sp-get.js "/_api/search/query?querytext='*'&refiners='FileType,Author'&rowlimit=0"

# Step 2 — apply a refinement filter
node scripts/sp-get.js "/_api/search/query?querytext='*'&refinementfilters='FileType:equals(\"pptx\")'&rowlimit=25"
```

---

## KQL (Keyword Query Language) Cheat Sheet

| Syntax | Description | Example |
|---|---|---|
| `property:value` | Exact match | `filetype:docx` |
| `property:"multi word"` | Phrase match | `author:"John Smith"` |
| `AND`, `OR`, `NOT` | Boolean operators | `budget AND Q3 NOT draft` |
| `filetype:ext` | File type filter | `filetype:xlsx` |
| `site:url` | Site scope | `site:https://contoso.sharepoint.com/sites/eng` |
| `author:"name"` | Author filter | `author:"Jane Doe"` |
| `lastModifiedTime>=date` | Date filter | `lastModifiedTime>=2024-01-01` |
| `path:"folder"` | Path filter | `path:"Shared Documents/Reports"` |
| `contentclass:value` | Content class | `contentclass:STS_ListItem_GenericList` |
| `IsDocument:true` | Documents only | `IsDocument:true` |

### Common content classes

| Content class | What it matches |
|---|---|
| `STS_ListItem_GenericList` | Custom list items |
| `STS_ListItem_DocumentLibrary` | Document library items |
| `STS_Site` | Sites |
| `STS_Web` | Webs (sub-sites) |
| `STS_ListItem_Links` | Links list items |

---

## Search Result Processing

### SP REST Search response structure

Results live at `PrimaryQueryResult.RelevantResults.Table.Rows[]`:

```jsonc
{
  "PrimaryQueryResult": {
    "RelevantResults": {
      "TotalRows": 142,
      "Table": {
        "Rows": [{
          "Cells": [
            { "Key": "Title", "Value": "Q3 Budget Report" },
            { "Key": "Path", "Value": "https://..." },
            { "Key": "Author", "Value": "Jane Doe" },
            { "Key": "LastModifiedTime", "Value": "2024-09-15T10:30:00Z" }
          ]
        }]
      }
    }
  }
}
```

---

## Patterns

### Pagination

Use `startrow` and `rowlimit`.

```
# Page 1
node scripts/sp-get.js "/_api/search/query?querytext='report'&startrow=0&rowlimit=25"

# Page 2
node scripts/sp-get.js "/_api/search/query?querytext='report'&startrow=25&rowlimit=25"
```

### Sorting

Use `sortlist` query parameter.

```
node scripts/sp-get.js "/_api/search/query?querytext='report'&sortlist='LastModifiedTime:descending'"
```

### Refiners (SP REST only)

Request refiners to get faceted counts, then apply refinement filters:

```
# Step 1 — request refiners
node scripts/sp-get.js "/_api/search/query?querytext='*'&refiners='FileType,Author'&rowlimit=0"

# Step 2 — apply a refinement filter
node scripts/sp-get.js "/_api/search/query?querytext='*'&refinementfilters='FileType:equals(\"pptx\")'&rowlimit=25"
```
