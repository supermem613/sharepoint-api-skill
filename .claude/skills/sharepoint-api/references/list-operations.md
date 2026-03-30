# SharePoint List Operations Reference

Reference for all list-related SharePoint REST API operations.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Get list items | Get items from a list |
| Create list items | Create new items |
| Update list items / batch update | Update items |
| Delete list items | Delete items |
| Search/filter items | Search/filter items |
| Get item metadata | Get item metadata |
| Get item by ID | Get single item |
| List items (paginated) | List items with pagination |
| Get item versions | Item version history |
| Restore item version | Restore a version |
| Create/update list | Create/update lists |
| Delete list | Delete a list |
| Get fields/columns | Get columns/fields |
| Delete field | Delete a column |
| Get views | Get views |
| Get view definition | Get view details |
| Delete view | Delete a view |
| Apply view formatting | Format a view |
| Apply column formatting | Format a column |

---

## Getting List Items

### Basic retrieval (`get_list_data`, `list_items`)

```bash
# Get items with selected fields
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$select=Title,Id,Status&\$top=100"

# Get a specific item by ID (get_item_by_identifier)
./sp-get.sh "/_api/web/lists(guid'{listId}')/items({itemId})"

# Get item metadata (get_list_item_metadata)
./sp-get.sh "/_api/web/lists(guid'{listId}')/items({itemId})?\$select=*,Author/Title,Editor/Title&\$expand=Author,Editor"
```

```powershell
# PowerShell equivalents
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/items?`$select=Title,Id,Status&`$top=100"
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/items({itemId})"
```

### Pagination

Use `$top` and `$skiptoken` for paging through large result sets:

```bash
# First page
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$top=100"

# Subsequent pages — use the odata.nextLink URL from the previous response
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$top=100&\$skiptoken=Paged%3DTRUE%26p_ID%3D100"
```

### Expanding lookup fields

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$select=Title,Category/Title&\$expand=Category"
```

### CAML queries for complex filtering (`find_items`)

Use `POST` to `GetItems` when OData `$filter` is insufficient:

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/GetItems" '{
  "query": {
    "__metadata": {"type": "SP.CamlQuery"},
    "ViewXml": "<View><Query><Where><And><Geq><FieldRef Name=\"Created\" /><Value Type=\"DateTime\">2024-01-01T00:00:00Z</Value></Geq><Eq><FieldRef Name=\"Status\" /><Value Type=\"Choice\">Active</Value></Eq></And></Where><OrderBy><FieldRef Name=\"Modified\" Ascending=\"FALSE\" /></OrderBy></Query><RowLimit>50</RowLimit></View>"
  }
}'
```

---

## Creating List Items

### Single item (`create_list_items`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items" '{
  "__metadata": {"type": "SP.Data.{ListName}ListItem"},
  "Title": "New Item",
  "Status": "Active",
  "DueDate": "2024-12-31T00:00:00Z",
  "Priority": 1
}'
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')/items" '{
  "__metadata": {"type": "SP.Data.{ListName}ListItem"},
  "Title": "New Item",
  "Status": "Active"
}'
```

### Determining the correct `__metadata.type`

The entity type name follows the pattern `SP.Data.{InternalListName}ListItem`. To find it:

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')?\$select=ListItemEntityTypeFullName"
```

The response `ListItemEntityTypeFullName` value is the string to use.

### Setting different field types

| Field Type | Example Value |
|------------|---------------|
| Text | `"Title": "Hello"` |
| Number | `"Amount": 42.5` |
| DateTime | `"DueDate": "2024-12-31T00:00:00Z"` |
| Choice | `"Status": "Active"` |
| Multi-Choice | `"Categories": {"results": ["Cat1", "Cat2"]}` |
| Lookup | `"CategoryId": 3` (use the `Id` suffix) |
| Multi-Lookup | `"CategoriesId": {"results": [1, 2, 3]}` |
| Person/User | `"AssignedToId": 15` (use the user's ID) |
| URL | `"Link": {"Url": "https://example.com", "Description": "Example"}` |
| Boolean | `"IsComplete": true` |

---

## Updating List Items

### Single item update (`update_list_items`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})" '{
  "__metadata": {"type": "SP.Data.{ListName}ListItem"},
  "Title": "Updated Title",
  "Status": "Complete"
}' PATCH
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')/items({itemId})" '{
  "__metadata": {"type": "SP.Data.{ListName}ListItem"},
  "Title": "Updated Title"
}' PATCH
```

> The helper scripts send `IF-MATCH: *` by default for PATCH requests. To use a
> specific ETag for concurrency control, pass the etag value from the item's
> `__metadata.etag` or `odata.etag` field.

### Batch updates (`update_batch_list_items`)

For updating multiple items, use the `$batch` endpoint:

```bash
# Build a batch request body — each changeset updates one item.
# The batch boundary and changeset structure are handled by the helper:
./sp-post.sh "/_api/\$batch" @batch-payload.txt
```

Batch payloads follow the OData multipart format. Each changeset contains a
PATCH request for a single item. Limit batches to **100 operations** per request.

---

## Deleting Items

### Single delete (`delete_list_item`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')/items({itemId})" '' DELETE
```

### Recycle instead of permanent delete

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})/recycle" ''
```

### Batch delete (`delete_items`)

Use the `$batch` endpoint with DELETE operations, or loop recycle calls:

```bash
# Recycle multiple items by ID
for id in 1 2 3 4; do
  ./sp-post.sh "/_api/web/lists(guid'{listId}')/items(${id})/recycle" ''
done
```

---

## Searching and Filtering Items

### OData `$filter` examples (`find_items`, `search_list_items`)

```bash
# Text equals
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=Title eq 'Project Alpha'"

# Number comparison
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=Amount gt 100"

# Date range
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=DueDate ge datetime'2024-01-01T00:00:00Z' and DueDate le datetime'2024-12-31T23:59:59Z'"

# Choice field
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=Status eq 'Active'"

# Lookup field (filter on ID)
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=CategoryId eq 3"

# Substring match
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=substringof('search term',Title)"

# Starts with
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=startswith(Title,'Project')"

# Combined filters
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=Status eq 'Active' and Priority le 2&\$orderby=DueDate asc"
```

```powershell
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/items?`$filter=Title eq 'Project Alpha'"
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/items?`$filter=Status eq 'Active' and Priority le 2&`$orderby=DueDate asc"
```

### CAML query for complex scenarios

See [CAML queries](#caml-queries-for-complex-filtering-find_items) above.

---

## List Management

### Create a list (`create_or_update_list`)

```bash
# Create a custom list (template 100)
./sp-post.sh "/_api/web/lists" '{
  "__metadata": {"type": "SP.List"},
  "Title": "My Custom List",
  "Description": "A project tracking list",
  "BaseTemplate": 100,
  "AllowContentTypes": true
}'

# Create a document library (template 101)
./sp-post.sh "/_api/web/lists" '{
  "__metadata": {"type": "SP.List"},
  "Title": "Project Documents",
  "Description": "Document library for project files",
  "BaseTemplate": 101
}'
```

```powershell
.\sp-post.ps1 "/_api/web/lists" '{
  "__metadata": {"type": "SP.List"},
  "Title": "My Custom List",
  "BaseTemplate": 100
}'
```

Common `BaseTemplate` values:

| Template | Type |
|----------|------|
| 100 | Custom List |
| 101 | Document Library |
| 104 | Announcements |
| 106 | Events/Calendar |
| 107 | Tasks |
| 108 | Discussion Board |
| 171 | Promoted Links |

### Update list properties

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')" '{
  "__metadata": {"type": "SP.List"},
  "Title": "Renamed List",
  "Description": "Updated description"
}' PATCH
```

### Delete a list (`delete_list`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')" '' DELETE
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')" '' DELETE
```

---

## Fields / Columns

### Get all fields (`get_fields_of_list`)

```bash
# Non-hidden fields only
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=Hidden eq false"

# All fields with specific properties
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$select=Title,InternalName,TypeAsString,Required,ReadOnlyField&\$filter=Hidden eq false"
```

```powershell
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/fields?`$filter=Hidden eq false"
```

### Add a field

```bash
# Text field
./sp-post.sh "/_api/web/lists(guid'{listId}')/fields" '{
  "__metadata": {"type": "SP.Field"},
  "Title": "ProjectCode",
  "FieldTypeKind": 2,
  "Required": true
}'

# Choice field
./sp-post.sh "/_api/web/lists(guid'{listId}')/fields" '{
  "__metadata": {"type": "SP.FieldChoice"},
  "Title": "Priority",
  "FieldTypeKind": 6,
  "Choices": {"results": ["Low", "Medium", "High", "Critical"]}
}'

# Number field
./sp-post.sh "/_api/web/lists(guid'{listId}')/fields" '{
  "__metadata": {"type": "SP.FieldNumber"},
  "Title": "Budget",
  "FieldTypeKind": 9,
  "MinimumValue": 0
}'
```

Field type kinds:

| FieldTypeKind | Type |
|---------------|------|
| 2 | Single line of text |
| 3 | Multi-line text |
| 4 | DateTime |
| 6 | Choice |
| 7 | Lookup |
| 8 | Boolean |
| 9 | Number |
| 10 | Currency |
| 11 | URL |
| 15 | Multi-Choice |
| 20 | User |

### Delete a field (`delete_field`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/fields/getbytitle('{fieldName}')" '' DELETE
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')/fields/getbytitle('{fieldName}')" '' DELETE
```

---

## Views

### Get all views (`get_views_of_list`)

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/views"
```

### Get view details (`get_view_definition`)

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')"

# Include view fields
./sp-get.sh "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')/viewfields"
```

```powershell
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')"
```

### Create a view

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/views" '{
  "__metadata": {"type": "SP.View"},
  "Title": "Active Items",
  "ViewQuery": "<Where><Eq><FieldRef Name=\"Status\" /><Value Type=\"Choice\">Active</Value></Eq></Where>",
  "ViewFields": {"results": ["Title", "Status", "DueDate", "AssignedTo"]},
  "RowLimit": 50,
  "PersonalView": false
}'
```

### Update a view

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')" '{
  "__metadata": {"type": "SP.View"},
  "Title": "Renamed View",
  "RowLimit": 100
}' PATCH
```

### Delete a view (`delete_view`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')" '' DELETE
```

### Apply view formatting (`apply_view_formatting`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/views(guid'{viewId}')/SetViewXml" '{
  "viewXml": "<View><Query><OrderBy><FieldRef Name=\"Modified\" Ascending=\"FALSE\" /></OrderBy></Query><ViewFields><FieldRef Name=\"Title\" /><FieldRef Name=\"Status\" /><FieldRef Name=\"DueDate\" /></ViewFields><RowLimit>30</RowLimit></View>"
}'
```

### Apply column formatting (`apply_column_formatting`)

Column formatting uses JSON to customize how a field renders:

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/fields/getbytitle('{fieldName}')" '{
  "__metadata": {"type": "SP.Field"},
  "CustomFormatter": "{\"$schema\":\"https://developer.microsoft.com/json-schemas/sp/v2/column-formatting.schema.json\",\"elmType\":\"div\",\"style\":{\"background-color\":\"=if(@currentField == '\''High'\'', '\''#f8d7da'\'', if(@currentField == '\''Medium'\'', '\''#fff3cd'\'', '\''#d4edda'\''))\"},\"txtContent\":\"@currentField\"}"
}' PATCH
```

---

## Item Versions

### Get version history (`list_item_versions`)

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items({itemId})/versions"
```

```powershell
.\sp-get.ps1 "/_api/web/lists(guid'{listId}')/items({itemId})/versions"
```

### Restore a version (`restore_item_version`)

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})/versions({versionId})/restoreByLabel" ''
```

```powershell
.\sp-post.ps1 "/_api/web/lists(guid'{listId}')/items({itemId})/versions({versionId})/restoreByLabel" ''
```

---

## Common Patterns

### Get list by title instead of GUID

```bash
./sp-get.sh "/_api/web/lists/getbytitle('My List')/items"
```

### Check if a list exists

```bash
./sp-get.sh "/_api/web/lists/getbytitle('My List')?\$select=Id,Title"
```

### Get list item count

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')?\$select=ItemCount"
```

### Combine $select, $expand, $filter, $orderby, $top

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$select=Title,Status,AssignedTo/Title,Category/Title&\$expand=AssignedTo,Category&\$filter=Status eq 'Active'&\$orderby=DueDate asc&\$top=50"
```
