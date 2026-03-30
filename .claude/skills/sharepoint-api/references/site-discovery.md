# Site Discovery & Structure Reference

> **Scope**: Discovering site structure, lists, libraries, metadata, and user resolution via SharePoint REST API.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Discover lists/libraries | List all lists and libraries in a site |
| Get list schema | Get list schema and metadata |
| Get fields/columns | Get columns/fields of a list |
| Get current list context | Identify the current context (which list/library) |
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
```

---

## Discovering All Lists and Libraries

Lists all non-hidden lists and libraries on a site. This is the entry point for understanding what data a site contains.

### REST API

```
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

```
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
| `Location` | Location field |
| `Computed` | Calculated/computed |

### Notes

- Always use `InternalName` (not `Title`) when constructing queries — `Title` is the display name and can contain spaces/special characters.
- `Choices` property is only populated for `Choice`/`MultiChoice` fields.
- Lookup fields have additional properties: `LookupList` (target list GUID) and `LookupField` (target column).

---

## Site Information

### REST API

```
# Current site info
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description,Language,Created"

# Site collection info
node scripts/sp-get.js "/_api/site?\$select=Id,Url,PrimaryUri"
```

Write-Host "Site: $($site.Title) at $($site.Url)"
```

---

## User Resolution

### Current User

```
# Current user via REST
node scripts/sp-get.js "/_api/web/currentuser?\$select=Id,Title,Email,LoginName"
```

### Site Users

```
# All site users (PrincipalType 1 = individual users)
node scripts/sp-get.js "/_api/web/siteusers?\$select=Id,Title,Email&\$filter=PrincipalType eq 1"

# Resolve user by email (for person field assignment)
node scripts/sp-get.js "/_api/web/siteusers?\$filter=Email eq 'user@contoso.com'&\$select=Id"
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
- `LoginName` format varies: `i:0#.f|membership|user@contoso.com` (claims-based).

---

---

## Lookup Field Resolution

Lookup fields reference items in another list. Resolving them requires knowing the target list and field.

### REST API

```
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

```
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

```
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

```
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

```
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

```
# 1. Get site info
node scripts/sp-get.js "/_api/web?\$select=Title,Url,Description"

# 2. Discover all lists/libraries
node scripts/sp-get.js "/_api/web/lists?\$filter=Hidden eq false&\$select=Id,Title,BaseTemplate,ItemCount"

# 3. For each interesting list, get its schema
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false and ReadOnlyField eq false&\$select=Title,InternalName,TypeAsString,Required"

# 4. Resolve lookup field targets
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=TypeAsString eq 'Lookup'&\$select=InternalName,LookupList,LookupField"
```

### Identifying Current Context

```
# The get_current_list_or_library tool uses the page URL context to determine which list/library the user is viewing
# For document libraries, the URL path contains the library name
# For lists, the URL typically contains /Lists/{listName}

# Get list by URL
node scripts/sp-get.js "/_api/web/GetList('/sites/MySite/Lists/MyList')?\$select=Id,Title,BaseTemplate"

# Get list by server-relative URL
node scripts/sp-get.js "/_api/web/GetList('{serverRelativeUrl}')?\$select=Id,Title,BaseTemplate,ItemCount"
```
