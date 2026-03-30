---
id: "28-item-versions"
name: "Get item version history"
category: "list-crud"
---

## Task

Pick a list item that has been modified at least once (or create and update one). Retrieve its version history and display each version's VersionLabel, Created date, and modified-by user.

## Checks

- [ ] Used sp-get.js to call /_api/web/lists/getByTitle('...')/items(ID)/versions
- [ ] Output includes at least one version entry
- [ ] Each version shows VersionLabel (e.g., "1.0", "2.0")
- [ ] Each version shows Created timestamp
