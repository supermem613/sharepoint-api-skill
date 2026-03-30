---
id: "26-create-list"
name: "Create a list"
category: "list-crud"
---

## Task

Create a new SharePoint list named "EVAL_TEST_LIST" with a description "Created by eval runner". After creation, retrieve the list and display its Title, Id, and ItemCount.

## Checks

- [ ] Used sp-post.js to POST to /_api/web/lists
- [ ] POST body includes Title "EVAL_TEST_LIST" and BaseTemplate 100 (generic list)
- [ ] Verified the list was created by retrieving it via getByTitle
- [ ] Output shows the list's Title, Id, and ItemCount (should be 0)
