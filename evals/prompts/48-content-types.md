---
id: "48-content-types"
name: "List content types"
category: "discovery"
---

## Task

List the content types available on a list (use the first non-hidden list). For each content type, display its Name, Id, and Description.

## Checks

- [ ] Used sp-get.js to call /_api/web/lists/getByTitle('...')/contenttypes
- [ ] Output includes at least one content type
- [ ] Each content type shows Name
- [ ] Each content type shows Id (StringId)
