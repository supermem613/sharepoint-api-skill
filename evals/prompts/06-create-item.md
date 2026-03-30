---
id: "06-create-item"
name: "Create a list item"
category: "list-crud"
---

## Task

Create a new item in a list on this site. Set the Title field to "EVAL_TEST_ITEM". After creation, note the list name and the new item's ID — these are needed by evals 07-update-item and 08-delete-item.

## Checks

- [ ] Used sp-post.js to make the API call
- [ ] POSTed to a list's /items endpoint
- [ ] Request body included Title set to "EVAL_TEST_ITEM"
- [ ] Got a success response (HTTP 201 or 200)
- [ ] Response contains the new item's Id
