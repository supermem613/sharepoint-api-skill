---
id: "43-check-permissions"
name: "Check site permissions"
category: "users"
---

## Task

Retrieve the role assignments for the current site. For each assignment, display the PrincipalId, the member (user or group name), and the role definition name (e.g., Full Control, Contribute, Read).

## Checks

- [ ] Used sp-get.js to call /_api/web/roleassignments with $expand=Member,RoleDefinitionBindings
- [ ] Output includes at least one role assignment
- [ ] Each assignment shows PrincipalId or Member LoginName/Title
- [ ] Each assignment shows the RoleDefinition Name (e.g., Full Control, Read)
