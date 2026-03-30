---
id: "35-list-pages"
name: "List site pages"
category: "pages"
---

## Task

List all site pages on the current SharePoint site. For each page, display its Title, Name (filename), and Id.

## Checks

- [ ] Used sp-get.js to call /_api/web/lists/getByTitle('Site Pages')/items or /_api/sitepages/pages
- [ ] Output includes at least one page entry
- [ ] Each page shows Title and Name (or FileName)
- [ ] Each page shows its Id
