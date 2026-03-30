---
id: "17-search-users"
name: "Search for users"
category: "users"
---

## Task

Retrieve the list of users on this SharePoint site, or search for a specific user by name or email. Display each user's Title and Email.

## Checks

- [ ] Used sp-get.js with /_api/web/siteusers OR graph-get.js with /users
- [ ] Output shows a list of users
- [ ] Each user entry includes a display name (Title or displayName)
- [ ] Each user entry includes an email (Email or mail) where available
