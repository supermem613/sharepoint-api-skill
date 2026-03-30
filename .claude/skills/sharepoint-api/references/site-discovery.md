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

---

## Discovering All Lists and Libraries

Lists all non-hidden lists and libraries on a site. This is the entry point for understanding what data a site contains.

### REST API

```bash
# Get all non-hidden lists and libraries
./sp-get.sh "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount,LastItemModifiedDate,Description"
```

### PowerShell

```powershell
$response = Invoke-SpRest -Url "/_api/web/lists?`$filter=Hidden eq false&`$select=Id,Title,BaseTemplate,ItemCount,LastItemModifiedDate,Description"
$response.value | Format-Table Title, BaseTemplate, ItemCount
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
./sp-get.sh "/_api/web/lists(guid'{listId}')?\$expand=Fields&\$select=Id,Title,Description,ItemCount,Fields/Title,Fields/InternalName,Fields/TypeAsString,Fields/Required,Fields/Choices"

# Just columns (non-hidden, non-readonly)
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required,Description"

# By list title instead of GUID
./sp-get.sh "/_api/web/lists/getbytitle('My List')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required,Description"
```

### PowerShell

```powershell
# Get fields for a list by title
$fields = Invoke-SpRest -Url "/_api/web/lists/getbytitle('My List')/fields?`$filter=Hidden eq false and ReadOnlyField eq false&`$select=Title,InternalName,TypeAsString,Required,Description"
$fields.value | Format-Table Title, InternalName, TypeAsString, Required
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
./sp-get.sh "/_api/web?\$select=Title,Url,Description,Language,Created"

# Site collection info
./sp-get.sh "/_api/site?\$select=Id,Url,PrimaryUri"
```

### Graph API

```bash
# Get site by hostname and path
./graph-get.sh "/v1.0/sites/{hostname}:{serverRelativePath}?\$select=id,displayName,webUrl,description"

# Example: contoso.sharepoint.com, path /sites/TeamSite
./graph-get.sh "/v1.0/sites/contoso.sharepoint.com:/sites/TeamSite?\$select=id,displayName,webUrl,description"
```

### PowerShell

```powershell
$site = Invoke-SpRest -Url "/_api/web?`$select=Title,Url,Description,Language,Created"
Write-Host "Site: $($site.Title) at $($site.Url)"
```

---

## Resolving Site IDs (for Graph API)

Many Graph API calls require a `siteId`. This section covers how to obtain it.

### REST API / Graph

```bash
# Get siteId from URL (needed for many Graph calls)
./graph-get.sh "/v1.0/sites/{hostname}:{serverRelativePath}"
# Response includes: id (format: {hostname},{siteCollectionId},{webId})

# Get all drives (document libraries) for a site
./graph-get.sh "/v1.0/sites/{siteId}/drives?\$select=id,name,webUrl"

# Get the default document library drive
./graph-get.sh "/v1.0/sites/{siteId}/drive?\$select=id,name,webUrl"
```

### PowerShell

```powershell
# Get siteId
$site = Invoke-GraphRest -Url "/v1.0/sites/contoso.sharepoint.com:/sites/TeamSite"
$siteId = $site.id

# Get drives for that site
$drives = Invoke-GraphRest -Url "/v1.0/sites/$siteId/drives?`$select=id,name,webUrl"
$drives.value | Format-Table name, id, webUrl
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
./sp-get.sh "/_api/web/currentuser?\$select=Id,Title,Email,LoginName"
```

### Site Users

```bash
# All site users (PrincipalType 1 = individual users)
./sp-get.sh "/_api/web/siteusers?\$select=Id,Title,Email&\$filter=PrincipalType eq 1"

# Resolve user by email (for person field assignment)
./sp-get.sh "/_api/web/siteusers?\$filter=Email eq 'user@contoso.com'&\$select=Id"
```

### Graph User Search

```bash
# Search for users by display name
./graph-get.sh "/v1.0/users?\$search=\"displayName:John\"&\$select=displayName,mail,id"

# Get specific user by email
./graph-get.sh "/v1.0/users/user@contoso.com?\$select=displayName,mail,id"
```

### PowerShell

```powershell
# Current user
$me = Invoke-SpRest -Url "/_api/web/currentuser?`$select=Id,Title,Email,LoginName"
Write-Host "Current user: $($me.Title) ($($me.Email))"

# Resolve user by email
$user = Invoke-SpRest -Url "/_api/web/siteusers?`$filter=Email eq 'user@contoso.com'&`$select=Id"
$userId = $user.value[0].Id
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
./sp-get.sh "/_api/v2.1/termstore"

# Get term groups
./sp-get.sh "/_api/v2.1/termstore/groups"
```

### Term Sets

```bash
# Get term sets in a group
./sp-get.sh "/_api/v2.1/termstore/groups/{groupId}/sets"

# Get terms in a term set
./sp-get.sh "/_api/v2.1/termstore/sets/{setId}/terms"

# Search for a specific term by label
./sp-get.sh "/_api/v2.1/termstore/sets/{setId}/terms?\$filter=labels/any(a:a/name eq 'term name')"
```

### PowerShell

```powershell
# Get term store
$termStore = Invoke-SpRest -Url "/_api/v2.1/termstore"

# Get all term sets in a group
$termSets = Invoke-SpRest -Url "/_api/v2.1/termstore/groups/$groupId/sets"
$termSets.value | Format-Table id, localizedNames

# Get terms
$terms = Invoke-SpRest -Url "/_api/v2.1/termstore/sets/$setId/terms"
$terms.value | ForEach-Object { Write-Host "$($_.labels[0].name) ($($_.id))" }
```

### Notes

- Taxonomy fields store a `TermGuid` and `Label` — both are needed when writing values.
- The term store API (`/_api/v2.1/termstore`) is the modern endpoint; the legacy `/_vti_bin/TaxonomyClientService.svc` is deprecated.
- Term labels can be multilingual — filter by `languageTag` if needed.

---

## Lookup Field Resolution

Lookup fields reference items in another list. Resolving them requires knowing the target list and field.

### REST API

```bash
# Get lookup field details (find target list and field)
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=InternalName eq '{lookupFieldName}'&\$select=LookupList,LookupField,Title,InternalName"

# Resolve lookup values — query the target list
./sp-get.sh "/_api/web/lists(guid'{targetListId}')/items?\$select=Id,{lookupField}&\$filter=Id eq {lookupValueId}"
```

### PowerShell

```powershell
# Get lookup field metadata
$field = Invoke-SpRest -Url "/_api/web/lists(guid'$listId')/fields?`$filter=InternalName eq '$lookupFieldName'&`$select=LookupList,LookupField"
$targetListId = $field.value[0].LookupList
$targetField = $field.value[0].LookupField

# Resolve the lookup value
$item = Invoke-SpRest -Url "/_api/web/lists(guid'$targetListId')/items?`$select=Id,$targetField&`$filter=Id eq $lookupValueId"
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
./sp-get.sh "/_api/web/regionalsettings?\$select=DateFormat,TimeZone,Time24,LocaleId"

# Get available time zones
./sp-get.sh "/_api/web/regionalsettings/timezones?\$select=Id,Description,Bias"
```

### PowerShell

```powershell
$regional = Invoke-SpRest -Url "/_api/web/regionalsettings?`$select=DateFormat,TimeZone,Time24,LocaleId"
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
./sp-get.sh "/_api/web/lists/getbytitle('My List')/items({itemId})?\$select={locationFieldName}"
```

### PowerShell

```powershell
$item = Invoke-SpRest -Url "/_api/web/lists/getbytitle('My List')/items($itemId)?`$select=$locationFieldName"
$location = $item.$locationFieldName | ConvertFrom-Json
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
./sp-get.sh "/_api/web/lists(guid'{listId}')/contenttypes?\$select=Name,Id,Description"

# Site-level content types
./sp-get.sh "/_api/web/contenttypes?\$select=Name,Id,Description"
```

### PowerShell

```powershell
$contentTypes = Invoke-SpRest -Url "/_api/web/lists(guid'$listId')/contenttypes?`$select=Name,Id,Description"
$contentTypes.value | Format-Table Name, Description
```

### Notes

- Content types define the schema (fields) for items in a list. A single list can have multiple content types.
- The `Id` is a hierarchical string (e.g., `0x0101` = Document). Child content types append to the parent ID.

---

## Site Pages

```bash
# List site pages
./sp-get.sh "/_api/web/lists/getbytitle('Site Pages')/items?\$select=Title,FileLeafRef,PromotedState"
```

### PowerShell

```powershell
$pages = Invoke-SpRest -Url "/_api/web/lists/getbytitle('Site Pages')/items?`$select=Title,FileLeafRef,PromotedState"
$pages.value | Format-Table Title, FileLeafRef, PromotedState
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
./sp-get.sh "/_api/web?\$select=Title,Url,Description"

# 2. Discover all lists/libraries
./sp-get.sh "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"

# 3. For each interesting list, get its schema
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required"

# 4. Resolve taxonomy fields if present
./sp-get.sh "/_api/v2.1/termstore/sets/{setId}/terms"

# 5. Resolve lookup field targets
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=TypeAsString eq 'Lookup'&\$select=InternalName,LookupList,LookupField"
```

### Identifying Current Context

```bash
# The get_current_list_or_library tool uses the page URL context to determine which list/library the user is viewing
# For document libraries, the URL path contains the library name
# For lists, the URL typically contains /Lists/{listName}

# Get list by URL
./sp-get.sh "/_api/web/GetList('/sites/MySite/Lists/MyList')?\$select=Id,Title,BaseTemplate"

# Get list by server-relative URL
./sp-get.sh "/_api/web/GetList('{serverRelativeUrl}')?\$select=Id,Title,BaseTemplate,ItemCount"
```
