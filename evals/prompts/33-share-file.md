---
id: "33-share-file"
name: "Create a sharing link"
category: "files"
---

## Task

Create an organization-wide sharing link for any existing file in the document library using the Graph API. Display the sharing link URL and its permissions scope.

## Checks

- [ ] Used graph-post.js to call /drives/{driveId}/items/{itemId}/createLink
- [ ] POST body includes type (e.g., "view") and scope (e.g., "organization")
- [ ] Output includes the generated sharing link URL
- [ ] Output includes the link's scope and type
