---
id: "08-delete-item"
name: "Delete a list item"
category: "list-crud"
---

## Task

Delete the test item updated in eval 07-update-item (the one with Title "EVAL_TEST_UPDATED"). You will need the list name and item ID from eval 06.

## Checks

- [ ] Used sp-post.js with DELETE method override (X-HTTP-Method header)
- [ ] Called /items({id}) endpoint with the correct item ID
- [ ] Got a success response (HTTP 200 or 204)
