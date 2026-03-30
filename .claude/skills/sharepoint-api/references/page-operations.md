# Page & News Post Operations

Reference for SharePoint site page and news post management via REST API.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Create/edit page | Create or edit site pages |
| Create pages | Create pages |
| Generate page content | Generate page content |
| Create text file | Create text-based files |

---

## Reading Pages

### List all site pages

```bash
node scripts/sp-get.js "/_api/web/lists/getbytitle('Site Pages')/items?\$select=Title,FileLeafRef,PromotedState,Author/Title,Modified&\$expand=Author&\$orderby=Modified desc"
```


### Get page content (returns canvas content as JSON)

```bash
node scripts/sp-get.js "/_api/sitepages/pages({pageId})?\$select=Title,Description,CanvasContent1,LayoutWebpartsContent"
```


### Read page as HTML

```bash
node scripts/sp-get.js "/_api/web/getfilebyserverrelativeurl('/sites/mysite/SitePages/mypage.aspx')/\$value"
```


---

## Creating Pages

### Create a blank modern page

```bash
node scripts/sp-post.js "/_api/sitepages/pages" '{
  "PageLayoutType": "Article",
  "Title": "My New Page"
}'
```


### Create a news post (PromotedState=2)

```bash
node scripts/sp-post.js "/_api/sitepages/pages" '{
  "PageLayoutType": "Article",
  "Title": "News Update",
  "PromotedState": 2
}'
```


### Publish a page (required after creation)

```bash
node scripts/sp-post.js "/_api/sitepages/pages({pageId})/publish" ''
```


---

## Editing Page Content

### Update page title and description

```bash
node scripts/sp-post.js "/_api/sitepages/pages({pageId})" '{
  "Title": "Updated Title",
  "Description": "Updated description"
}' PATCH
```


### Set canvas content (web parts / sections)

```bash
node scripts/sp-post.js "/_api/sitepages/pages({pageId})/savepage" '{
  "CanvasContent1": "[{\"controlType\":4,\"id\":\"...\",\"innerHTML\":\"<p>Hello World</p>\"}]"
}'
```


---

## Deleting Pages

### Delete a page (sends to recycle bin)

```bash
node scripts/sp-post.js "/_api/web/getfilebyserverrelativeurl('/sites/mysite/SitePages/mypage.aspx')" '' DELETE
```


---

## Page Properties Reference

| Property | Values | Description |
|----------|--------|-------------|
| `PageLayoutType` | `"Article"` | Standard content page |
| | `"Home"` | Site home page |
| | `"SingleWebPartAppPage"` | Full-page web part app |
| `PromotedState` | `0` | Regular page |
| | `2` | News post |
| `CanvasContent1` | JSON array | Web part controls and section layout |
| `LayoutWebpartsContent` | JSON array | Page header / title region web parts |

## Common Workflow: Create and Publish a News Post

```bash
# 1. Create the news post
PAGE_ID=$(node scripts/sp-post.js "/_api/sitepages/pages" '{
  "PageLayoutType": "Article",
  "Title": "Weekly Update",
  "PromotedState": 2
}' | jq -r '.Id')

# 2. Add content
node scripts/sp-post.js "/_api/sitepages/pages(${PAGE_ID})/savepage" '{
  "CanvasContent1": "[{\"controlType\":4,\"id\":\"txt-1\",\"innerHTML\":\"<p>This week we shipped...</p>\"}]"
}'

# 3. Publish
node scripts/sp-post.js "/_api/sitepages/pages(${PAGE_ID})/publish" ''
```
