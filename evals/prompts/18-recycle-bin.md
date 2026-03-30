---
id: "18-recycle-bin"
name: "View recycle bin"
category: "advanced"
---

## Task

Retrieve the contents of this site's recycle bin. For each item, show its Title (LeafName), deletion date (DeletedDate), and who deleted it (DeletedByName). If the recycle bin is empty, confirm that.

## Checks

- [ ] Used sp-get.js to make the API call
- [ ] Called /_api/web/recyclebin
- [ ] Output shows recycled items with names and deletion dates, OR confirms the bin is empty
