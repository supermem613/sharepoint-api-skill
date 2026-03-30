---
id: "46-resolve-site-id"
name: "Resolve site ID from URL"
category: "discovery"
---

## Task

Given the current SharePoint site URL, resolve its Microsoft Graph site ID using the Graph API. Display the site's id, displayName, and webUrl.

## Checks

- [ ] Used graph-get.js to call /sites/{hostname}:/{server-relative-path} or /sites/{hostname}
- [ ] Output includes the Graph site id (format: {hostname},{siteCollectionId},{webId})
- [ ] Output includes displayName
- [ ] Output includes webUrl
