---
id: "01-auth"
name: "Authenticate to SharePoint"
category: "auth"
---

## Task

Authenticate to the current SharePoint site using the skill's auth script. After authenticating, verify that the credentials work by making a GET request to `/_api/web` and displaying the site's Title.

## Checks

- [ ] Ran sp-auth-wrapper.js or sp-auth.js to authenticate
- [ ] SP_COOKIES or SP_SITE environment variable is set after auth
- [ ] Made a GET request to /_api/web using sp-get.js
- [ ] Output includes the site's Title property
