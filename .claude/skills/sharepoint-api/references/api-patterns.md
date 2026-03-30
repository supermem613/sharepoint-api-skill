# SharePoint REST API Patterns Reference

Common patterns for calling SharePoint REST APIs.

---

## 1. Request Digest (X-RequestDigest)

SharePoint REST **POST**, **PUT**, **DELETE**, and **PATCH** requests require a valid request digest token for cross-site request forgery (CSRF) protection.

### Getting the digest

```bash
# The sp-post.js script handles this automatically.
# For manual use:
DIGEST=$(node scripts/sp-get.js "/_api/contextinfo" | jq -r '.FormDigestValue')
```


### Manual header usage

```bash
curl -X POST "$SITE_URL/_api/web/lists" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json;odata=verbose" \
  -H "Content-Type: application/json;odata=verbose" \
  -H "X-RequestDigest: $DIGEST" \
  -d '{"__metadata":{"type":"SP.List"},"Title":"My List","BaseTemplate":100}'
```

> **Note:** GET requests do not require a request digest.

---

## 2. OData Query Options

Append query options to any REST endpoint to shape the response.

| Option     | Purpose              | Example                                              |
|------------|----------------------|------------------------------------------------------|
| `$select`  | Choose fields        | `?$select=Title,Id,Created`                          |
| `$expand`  | Expand lookups       | `?$expand=Fields` or `?$expand=Author`               |
| `$filter`  | Filter items         | `?$filter=Title eq 'Test'`                           |
| `$orderby` | Sort results         | `?$orderby=Modified desc`                            |
| `$top`     | Limit result count   | `?$top=100`                                          |
| `$skip`    | Skip N results       | `?$skip=200`                                         |

### Filter operators

```
eq, ne, gt, lt, ge, le
substringof('value', FieldName)
startswith(FieldName, 'value')
```

### Combining options

```bash
node scripts/sp-get.js "/_api/web/lists/getbytitle('Tasks')/items?\$select=Title,Id,Status&\$filter=Status eq 'Active'&\$top=50&\$orderby=Created desc"
```


> **Tip:** In bash, escape `$` with `\$` inside double quotes.

---

## 3. Pagination

Responses include `odata.nextLink` when more results are available.

```bash
URL="/_api/web/lists/getbytitle('LargeList')/items?\$top=100"

while [ -n "$URL" ]; do
  RESPONSE=$(node scripts/sp-get.js "$URL")
  echo "$RESPONSE" | jq '.value[]'
  URL=$(echo "$RESPONSE" | jq -r '.["odata.nextLink"] // empty')
done
```

while ($url) {
}
```

---

## 4. Error Handling

### Error response formats

**SharePoint REST:**
```json
{
  "odata.error": {
    "code": "-2130575251, Microsoft.SharePoint.SPException",
    "message": { "value": "List 'Nonexistent' does not exist..." }
  }
}
```

### Common HTTP status codes

| Code | Meaning                | Action                                         |
|------|------------------------|-------------------------------------------------|
| 401  | Unauthorized           | Cookies expired — re-run `sp-auth`              |
| 403  | Forbidden              | Check site/list permissions                     |
| 404  | Not found              | Verify the URL, list name, or item ID           |
| 429  | Throttled              | Respect `Retry-After` header, then retry        |
| 500  | Internal server error  | Retry after a short delay; check query syntax   |

### Throttling pattern

```bash
RESPONSE=$(curl -s -w "\n%{http_code}" "$REQUEST_URL" -H "Authorization: Bearer $TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "429" ]; then
  RETRY_AFTER=$(curl -sI "$REQUEST_URL" -H "Authorization: Bearer $TOKEN" | grep -i 'Retry-After' | awk '{print $2}')
  sleep "${RETRY_AFTER:-5}"
  # Retry the request
fi
```

---

## 5. Content Types and Metadata

### OData modes

| Mode              | Header Value                               | Use Case                              |
|-------------------|--------------------------------------------|---------------------------------------|
| `odata=nometadata`| `application/json;odata=nometadata`        | GET — smaller responses, less overhead|
| `odata=verbose`   | `application/json;odata=verbose`           | POST/PATCH — required for `__metadata`|
| `odata=minimalmetadata` | `application/json;odata=minimalmetadata` | Default — balanced                 |

### __metadata.type for POST/PATCH (odata=verbose)

When creating or updating items with `odata=verbose`, include the `__metadata.type` property.

**List items:** `SP.Data.{ListInternalName}ListItem`
- Internal name is Title-cased with spaces removed.
- "My Tasks" → `SP.Data.MyTasksListItem`
- "Documents" → `SP.Data.DocumentsListItem`

**Lists:** `SP.List`

```bash
node scripts/sp-post.js "/_api/web/lists/getbytitle('Tasks')/items" \
  '{"__metadata":{"type":"SP.Data.TasksListItem"},"Title":"New Task","Status":"Active"}'
```


---

## 6. CAML Queries

Use CAML when you need complex queries that `$filter` cannot express: nested AND/OR conditions, lookup field queries, or fine-grained control over returned fields.

### Endpoint

```
POST /_api/web/lists/getbytitle('{ListName}')/GetItems
```

### Basic structure

```xml
<View>
  <ViewFields>
    <FieldRef Name="Title" />
    <FieldRef Name="Status" />
    <FieldRef Name="Priority" />
    <FieldRef Name="Created" />
  </ViewFields>
  <Query>
    <Where>
      <!-- conditions -->
    </Where>
    <OrderBy>
      <FieldRef Name="Created" Ascending="FALSE" />
    </OrderBy>
  </Query>
  <RowLimit>50</RowLimit>
</View>
```

### Common operators

| Operator      | Meaning                    |
|---------------|----------------------------|
| `<Eq>`        | Equal                      |
| `<Neq>`       | Not equal                  |
| `<Gt>`        | Greater than               |
| `<Lt>`        | Less than                  |
| `<Geq>`       | Greater than or equal      |
| `<Leq>`       | Less than or equal         |
| `<Contains>`  | Contains substring         |
| `<BeginsWith>`| Starts with                |

### Example: Status = 'Active' AND Priority > 2, sorted by Created

```bash
CAML='<View>
  <ViewFields>
    <FieldRef Name="Title" />
    <FieldRef Name="Status" />
    <FieldRef Name="Priority" />
    <FieldRef Name="Created" />
  </ViewFields>
  <Query>
    <Where>
      <And>
        <Eq>
          <FieldRef Name="Status" />
          <Value Type="Text">Active</Value>
        </Eq>
        <Gt>
          <FieldRef Name="Priority" />
          <Value Type="Number">2</Value>
        </Gt>
      </And>
    </Where>
    <OrderBy>
      <FieldRef Name="Created" Ascending="FALSE" />
    </OrderBy>
  </Query>
  <RowLimit>50</RowLimit>
</View>'

node scripts/sp-post.js "/_api/web/lists/getbytitle('Tasks')/GetItems" \
  "{\"query\":{\"__metadata\":{\"type\":\"SP.CamlQuery\"},\"ViewXml\":\"$CAML\"}}"
```


---

## 7. Batch Requests

Use batching when creating or updating more than ~5 items to reduce round trips.

### SharePoint REST batch

```
POST /_api/$batch
Content-Type: multipart/mixed; boundary=batch_id
```

Each changeset in the multipart body contains individual requests. The `node scripts/sp-post.js` script does not handle batching — construct the multipart body manually or use a helper.

> **Limit:** Keep changesets to a reasonable size for optimal performance.

---

## 8. Common Headers

### SharePoint REST

| Header            | When Required              | Value                                  |
|-------------------|----------------------------|----------------------------------------|
| `Authorization`   | Always                     | `Bearer <token>`                       |
| `Accept`          | Always                     | `application/json;odata=nometadata`    |
| `Content-Type`    | POST/PATCH/PUT             | `application/json;odata=verbose`       |
| `X-RequestDigest` | POST/PATCH/PUT/DELETE      | From `/_api/contextinfo`               |
| `IF-MATCH`        | Update/delete (concurrency)| `*` (overwrite) or specific etag       |
| `X-HTTP-Method`   | MERGE or DELETE via POST   | `MERGE` or `DELETE`                    |

---

## 9. URL Encoding

- Spaces → `%20`
- Single quotes inside values must be doubled: `'O''Brien'`
- Server-relative URLs in functions must be encoded:

```bash
# Encode the path argument
node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('/sites/my%20site/Shared%20Documents/report.docx')"
```
