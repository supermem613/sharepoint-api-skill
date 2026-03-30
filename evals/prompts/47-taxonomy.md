---
id: "47-taxonomy"
name: "Get term store and term sets"
category: "discovery"
---

## Task

Retrieve the site's term store information using the Graph API or SharePoint taxonomy endpoints. List available term groups and term sets. For each term set, display its Name and Id.

## Checks

- [ ] Used graph-get.js to call /sites/{siteId}/termStore or sp-get.js with taxonomy endpoint
- [ ] Output includes term store information (name or id)
- [ ] Output lists at least one term group or term set
- [ ] Each term set shows Name and Id
