---
id: "34-file-versions"
name: "Get file version history"
category: "files"
---

## Task

Retrieve the version history for a file that has multiple versions (or upload, then update a file to create versions). Display each version's VersionLabel, Size, and Created date.

## Checks

- [ ] Used sp-get.js to call /_api/web/getFileByServerRelativeUrl('...')/versions
- [ ] Output includes at least one version entry
- [ ] Each version shows VersionLabel (e.g., "1.0", "2.0")
- [ ] Each version shows Size or Created timestamp
