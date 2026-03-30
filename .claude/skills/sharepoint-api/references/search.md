# SharePoint Search API Reference

> **Operations covered:** Enterprise file search, list item search, semantic search, content search, item filtering

---

## Microsoft Graph Search API (Primary — enterprise-wide)

The Graph Search API is the modern way to search across M365 content. It provides a unified search experience across SharePoint, OneDrive, and other M365 services.

### Search files across SharePoint/OneDrive

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["driveItem"],
    "query": {"queryString": "budget report Q3"},
    "from": 0,
    "size": 25
  }]
}'
```

```powershell
$body = @{
    requests = @(@{
        entityTypes = @("driveItem")
        query       = @{ queryString = "budget report Q3" }
        from        = 0
        size        = 25
    })
} | ConvertTo-Json -Depth 5

Invoke-MgGraphRequest -Method POST -Uri "/v1.0/search/query" -Body $body
```

### Search list items

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["listItem"],
    "query": {"queryString": "contentclass:STS_ListItem_GenericList project plan"},
    "from": 0,
    "size": 25
  }]
}'
```

```powershell
$body = @{
    requests = @(@{
        entityTypes = @("listItem")
        query       = @{ queryString = "contentclass:STS_ListItem_GenericList project plan" }
        from        = 0
        size        = 25
    })
} | ConvertTo-Json -Depth 5

Invoke-MgGraphRequest -Method POST -Uri "/v1.0/search/query" -Body $body
```

### Search people

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["person"],
    "query": {"queryString": "engineering manager"}
  }]
}'
```

### Search messages (emails, Teams)

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["message"],
    "query": {"queryString": "budget approval"}
  }]
}'
```

### Search sites

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["site"],
    "query": {"queryString": "engineering"}
  }]
}'
```

```powershell
$body = @{
    requests = @(@{
        entityTypes = @("site")
        query       = @{ queryString = "engineering" }
    })
} | ConvertTo-Json -Depth 5

Invoke-MgGraphRequest -Method POST -Uri "/v1.0/search/query" -Body $body
```

---

## SharePoint REST Search API (Classic — site-scoped)

For more granular SharePoint-specific search when you need refiners, managed properties, or site-scoped queries.

### Basic keyword search

```bash
./sp-get.sh "/_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=25"
```

```powershell
Invoke-RestMethod `
    -Uri "$SpSiteUrl/_api/search/query?querytext='budget report'&selectproperties='Title,Path,Author,LastModifiedTime'&rowlimit=25" `
    -Headers @{ Authorization = "Bearer $token"; Accept = "application/json" }
```

### Search within current site

```bash
./sp-get.sh "/_api/search/query?querytext='budget report site:$SP_SITE'&selectproperties='Title,Path'"
```

### Search with refiners (facets)

```bash
./sp-get.sh "/_api/search/query?querytext='*'&refinementfilters='FileType:equals(\"docx\")'&selectproperties='Title,Path,Size'"
```

```powershell
$filter = 'FileType:equals("docx")'
Invoke-RestMethod `
    -Uri "$SpSiteUrl/_api/search/query?querytext='*'&refinementfilters='$filter'&selectproperties='Title,Path,Size'" `
    -Headers @{ Authorization = "Bearer $token"; Accept = "application/json" }
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

### Graph Search response structure

Results live at `hitsContainers[0].hits[]`. Each hit contains a `resource` object:

```jsonc
{
  "hitsContainers": [{
    "total": 142,
    "moreResultsAvailable": true,
    "hits": [{
      "hitId": "...",
      "rank": 1,
      "summary": "...highlighted <c0>budget</c0> snippet...",
      "resource": {
        "@odata.type": "#microsoft.graph.driveItem",
        "name": "Q3 Budget Report.docx",
        "webUrl": "https://...",
        "lastModifiedDateTime": "2024-09-15T10:30:00Z",
        "lastModifiedBy": { "user": { "displayName": "Jane Doe" } },
        "size": 245760
      }
    }]
  }]
}
```

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

**Graph:** Use `from` (zero-based offset) and `size` (page size).

```bash
# Page 1
./graph-post.sh "/v1.0/search/query" '{"requests":[{"entityTypes":["driveItem"],"query":{"queryString":"report"},"from":0,"size":25}]}'

# Page 2
./graph-post.sh "/v1.0/search/query" '{"requests":[{"entityTypes":["driveItem"],"query":{"queryString":"report"},"from":25,"size":25}]}'
```

**SP REST:** Use `startrow` and `rowlimit`.

```bash
# Page 1
./sp-get.sh "/_api/search/query?querytext='report'&startrow=0&rowlimit=25"

# Page 2
./sp-get.sh "/_api/search/query?querytext='report'&startrow=25&rowlimit=25"
```

### Sorting

**Graph:** Use `sortProperties` in the request body.

```bash
./graph-post.sh "/v1.0/search/query" '{
  "requests": [{
    "entityTypes": ["driveItem"],
    "query": {"queryString": "report"},
    "sortProperties": [{"name": "lastModifiedDateTime", "isDescending": true}]
  }]
}'
```

**SP REST:** Use `sortlist` query parameter.

```bash
./sp-get.sh "/_api/search/query?querytext='report'&sortlist='LastModifiedTime:descending'"
```

### Refiners (SP REST only)

Request refiners to get faceted counts, then apply refinement filters:

```bash
# Step 1 — request refiners
./sp-get.sh "/_api/search/query?querytext='*'&refiners='FileType,Author'&rowlimit=0"

# Step 2 — apply a refinement filter
./sp-get.sh "/_api/search/query?querytext='*'&refinementfilters='FileType:equals(\"pptx\")'&rowlimit=25"
```
