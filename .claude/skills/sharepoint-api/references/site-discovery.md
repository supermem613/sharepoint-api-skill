# Site Discovery & Structure Reference

> **Scope**: Discovering site structure, lists, libraries, metadata, taxonomy, and user resolution via SharePoint REST API and Microsoft Graph.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Discover lists/libraries | List all lists and libraries in a site |
| Get list schema | Get list schema and metadata |
| Get fields/columns | Get columns/fields of a list |
| Get current list context | Identify the current context (which list/library) |
| Get taxonomy/term sets | Taxonomy and managed metadata resolution |
| Get lookup info | Lookup field resolution (cross-list references) |
| Get date/time info | Date/time field formatting and regional settings |
| Get user info | User resolution (person fields, current user) |
| Get location info | Location field resolution |

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/web                                                    # Site info
/_api/web?$select=Title,Url,Description                      # Site info (selected fields)
/_api/web/lists                                              # All lists
/_api/web/lists?$filter=Hidden eq false                      # Non-hidden lists
/_api/web/lists(guid'{listId}')                              # Single list
/_api/web/lists(guid'{listId}')/fields                       # List columns
/_api/web/lists(guid'{listId}')/contenttypes                 # Content types
/_api/web/siteusers                                          # Site users
/_api/web/currentuser                                        # Current user
/_api/v2.1/termstore                                         # Taxonomy term store
/_api/v2.1/termstore/groups/{groupId}/sets                   # Term sets
/_api/v2.1/termstore/sets/{setId}/terms                      # Terms
/v1.0/sites/{hostname}:{path}                                # Resolve site ID (Graph)
/v1.0/sites/{siteId}/lists                                   # Lists via Graph
/v1.0/sites/{siteId}/drives                                  # Document libraries (Graph)
```

---

## Discovering All Lists and Libraries

Lists all non-hidden lists and libraries on a site. This is the entry point for understanding what data a site contains.

### REST API

```bash
# Get all non-hidden lists and libraries
node scripts/sp-get.js "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount,LastItemModifiedDate,Description"
```


### BaseTemplate Reference

| Value | Type |
|-------|------|
| 100 | Generic List |
| 101 | Document Library |
| 104 | Announcements |
| 106 | Events (Calendar) |
| 107 | Tasks |
| 171 | Promoted Links |

### Response Shape

```json
{
  "value": [
    {
      "Id": "guid",
      "Title": "Documents",
      "BaseTemplate": 101,
      "ItemCount": 42,
      "LastItemModifiedDate": "2024-01-15T10:30:00Z",
      "Description": "Shared documents library"
    }
  ]
}
```

### Notes

- `BaseTemplate` distinguishes lists (100) from document libraries (101) — this is the most reliable way to tell them apart.
- Hidden lists (e.g., `_catalogs`, `Style Library`) are filtered out. Include them with `Hidden eq true` if needed for admin scenarios.
- `ItemCount` may be approximate for large lists.

---

## Getting List Schema

Retrieve full metadata about a specific list, including its fields.

### REST API

```bash
# Full list info with fields
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')?\$expand=Fields&\$select=Id,Title,Description,ItemCount,Fields/Title,Fields/InternalName,Fields/TypeAsString,Fields/Required,Fields/Choices"

# Just columns (non-hidden, non-readonly)
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required,Description"

# By list title instead of GUID
node scripts/sp-get.js "/_api/web/lists/getbytitle('My List')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required,Description"
```


### Common Field TypeAsString Values

| TypeAsString | Meaning |
|-------------|---------|
| `Text` | Single line of text |
| `Note` | Multi-line text |
| `Number` | Numeric value |
| `Currency` | Currency value |
| `DateTime` | Date and time |
| `Choice` | Single choice |
| `MultiChoice` | Multiple choices |
| `Lookup` | Lookup to another list |
| `Boolean` | Yes/No |
| `User` | Person or group |
| `UserMulti` | Multiple people |
| `URL` | Hyperlink |
| `Taxonomy` | Managed metadata (single) |
| `TaxonomyMulti` | Managed metadata (multi) |
| `Location` | Location field |
| `Computed` | Calculated/computed |

### Notes

- Always use `InternalName` (not `Title`) when constructing queries — `Title` is the display name and can contain spaces/special characters.
- `Choices` property is only populated for `Choice`/`MultiChoice` fields.
- Lookup fields have additional properties: `LookupList` (target list GUID) and `LookupField` (target column).

---

## Site Information

### REST API

```bash
# Current site info
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description,Language,Created"

# Site collection info
node scripts/sp-get.js "/_api/site?\$select=Id,Url,PrimaryUri"
```

### Graph API

```bash
# Get site by hostname and path
node scripts/graph-get.js "/v1.0/sites/{hostname}:{serverRelativePath}?\$select=id,displayName,webUrl,description"

# Example: contoso.sharepoint.com, path /sites/TeamSite
node scripts/graph-get.js "/v1.0/sites/contoso.sharepoint.com:/sites/TeamSite?\$select=id,displayName,webUrl,description"
```

Write-Host "Site: $($site.Title) at $($site.Url)"
```

---

## Resolving Site IDs (for Graph API)

Many Graph API calls require a `siteId`. This section covers how to obtain it.

### REST API / Graph

```bash
# Get siteId from URL (needed for many Graph calls)
node scripts/graph-get.js "/v1.0/sites/{hostname}:{serverRelativePath}"
# Response includes: id (format: {hostname},{siteCollectionId},{webId})

# Get all drives (document libraries) for a site
node scripts/graph-get.js "/v1.0/sites/{siteId}/drives?\$select=id,name,webUrl"

# Get the default document library drive
node scripts/graph-get.js "/v1.0/sites/{siteId}/drive?\$select=id,name,webUrl"
```


### Notes

- The Graph `siteId` format is `{hostname},{siteCollectionId},{webId}` — all three parts are needed.
- A "drive" in Graph corresponds to a document library in SharePoint.
- The default drive is the primary document library (usually "Documents").

---

## User Resolution

### Current User

```bash
# Current user via REST
node scripts/sp-get.js "/_api/web/currentuser?\$select=Id,Title,Email,LoginName"
```

### Site Users

```bash
# All site users (PrincipalType 1 = individual users)
node scripts/sp-get.js "/_api/web/siteusers?\$select=Id,Title,Email&\$filter=PrincipalType eq 1"

# Resolve user by email (for person field assignment)
node scripts/sp-get.js "/_api/web/siteusers?\$filter=Email eq 'user@contoso.com'&\$select=Id"
```

### Graph User Search

```bash
# Search for users by display name
node scripts/graph-get.js "/v1.0/users?\$search=\"displayName:John\"&\$select=displayName,mail,id"

# Get specific user by email
node scripts/graph-get.js "/v1.0/users/user@contoso.com?\$select=displayName,mail,id"
```

### PrincipalType Values

| Value | Type |
|-------|------|
| 1 | User |
| 2 | Distribution List |
| 4 | Security Group |
| 8 | SharePoint Group |

### Notes

- The SharePoint user `Id` (integer) is what person/user fields expect — not the Azure AD GUID.
- Graph `$search` requires the `ConsistencyLevel: eventual` header.
- `LoginName` format varies: `i:0#.f|membership|user@contoso.com` (claims-based).

---

## Taxonomy / Managed Metadata

### Term Store

```bash
# Get the term store
node scripts/sp-get.js "/_api/v2.1/termstore"

# Get term groups
node scripts/sp-get.js "/_api/v2.1/termstore/groups"
```

### Term Sets

```bash
# Get term sets in a group
node scripts/sp-get.js "/_api/v2.1/termstore/groups/{groupId}/sets"

# Get terms in a term set
node scripts/sp-get.js "/_api/v2.1/termstore/sets/{setId}/terms"

# Search for a specific term by label
node scripts/sp-get.js "/_api/v2.1/termstore/sets/{setId}/terms?\$filter=labels/any(a:a/name eq 'term name')"
```


### Notes

- Taxonomy fields store a `TermGuid` and `Label` — both are needed when writing values.
- The term store API (`/_api/v2.1/termstore`) is the modern endpoint; the legacy `/_vti_bin/TaxonomyClientService.svc` is deprecated.
- **`/_api/v2.1/termstore` requires OAuth bearer token authentication** (SP_TOKEN). Cookie-based auth returns 403. **Preferred alternative:** Use Microsoft Graph: `node scripts/graph-get.js "/v1.0/sites/{siteId}/termStore"` (requires GRAPH_TOKEN, which is captured automatically).
- Term labels can be multilingual — filter by `languageTag` if needed.

---

## Lookup Field Resolution

Lookup fields reference items in another list. Resolving them requires knowing the target list and field.

### REST API

```bash
# Get lookup field details (find target list and field)
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=InternalName eq '{lookupFieldName}'&\$select=LookupList,LookupField,Title,InternalName"

# Resolve lookup values — query the target list
node scripts/sp-get.js "/_api/web/lists(guid'{targetListId}')/items?\$select=Id,{lookupField}&\$filter=Id eq {lookupValueId}"
```

### Notes

- `LookupList` returns the GUID of the target list (without braces).
- `LookupField` is typically `Title` but can be any column in the target list.
- Multi-value lookups return an array of `{ Id, Value }` objects.

---

## Date/Time Formatting

### REST API

```bash
# Get regional settings (date format, time zone)
node scripts/sp-get.js "/_api/web/regionalsettings?\$select=DateFormat,TimeZone,Time24,LocaleId"

# Get available time zones
node scripts/sp-get.js "/_api/web/regionalsettings/timezones?\$select=Id,Description,Bias"
```

Write-Host "Date format: $($regional.DateFormat), 24h: $($regional.Time24)"
```

### Notes

- SharePoint stores dates in UTC. The regional settings determine display formatting.
- When writing DateTime values via REST, use ISO 8601 format: `2024-01-15T10:30:00Z`.
- `DateFormat` values: 0 = MM/DD/YYYY, 1 = DD/MM/YYYY, 2 = YYYY/MM/DD.

---

## Location Field Resolution

```bash
# Location fields use Bing Maps integration — values are JSON objects
# Read a location field value from a list item
node scripts/sp-get.js "/_api/web/lists/getbytitle('My List')/items({itemId})?\$select={locationFieldName}"
```

Write-Host "Address: $($location.Address.Street), $($location.Address.City)"
```

### Location Field JSON Structure

```json
{
  "DisplayName": "Microsoft Building 25",
  "Address": {
    "Street": "16070 NE 36th Way",
    "City": "Redmond",
    "State": "WA",
    "CountryOrRegion": "US",
    "PostalCode": "98052"
  },
  "Coordinates": {
    "Latitude": 47.6423,
    "Longitude": -122.1372
  }
}
```

---

## Content Types

### REST API

```bash
# List content types for a specific list
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/contenttypes?\$select=Name,Id,Description"

# Site-level content types
node scripts/sp-get.js "/_api/web/contenttypes?\$select=Name,Id,Description"
```


### Notes

- Content types define the schema (fields) for items in a list. A single list can have multiple content types.
- The `Id` is a hierarchical string (e.g., `0x0101` = Document). Child content types append to the parent ID.

---

## Site Pages

```bash
# List site pages
node scripts/sp-get.js "/_api/web/lists/getbytitle('Site Pages')/items?\$select=Title,FileLeafRef,PromotedState"
```


### PromotedState Values

| Value | Meaning |
|-------|---------|
| 0 | Normal page |
| 1 | News post (pending) |
| 2 | News post (published) |

---

## Common Patterns

### Full Site Discovery Sequence

A typical site discovery flow combines multiple calls:

```bash
# 1. Get site info
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description"

# 2. Discover all lists/libraries
node scripts/sp-get.js "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"

# 3. For each interesting list, get its schema
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required"

# 4. Resolve taxonomy fields if present
node scripts/sp-get.js "/_api/v2.1/termstore/sets/{setId}/terms"

# 5. Resolve lookup field targets
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=TypeAsString eq 'Lookup'&\$select=InternalName,LookupList,LookupField"
```

### Identifying Current Context

```bash
# The get_current_list_or_library tool uses the page URL context to determine which list/library the user is viewing
# For document libraries, the URL path contains the library name
# For lists, the URL typically contains /Lists/{listName}

# Get list by URL
node scripts/sp-get.js "/_api/web/GetList('/sites/MySite/Lists/MyList')?\$select=Id,Title,BaseTemplate"

# Get list by server-relative URL
node scripts/sp-get.js "/_api/web/GetList('{serverRelativeUrl}')?\$select=Id,Title,BaseTemplate,ItemCount"
```
