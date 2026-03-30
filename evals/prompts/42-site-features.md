---
id: "42-site-features"
name: "List site features"
category: "advanced"
---

## Task

List all activated features on the current site (web-scoped features). For each feature, display its DefinitionId and DisplayName.

## Checks

- [ ] Used sp-get.js to call /_api/web/features
- [ ] Output includes at least one feature entry
- [ ] Each feature shows DefinitionId (GUID)
- [ ] Each feature shows DisplayName
