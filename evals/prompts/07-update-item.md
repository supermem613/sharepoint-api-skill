---
id: "07-update-item"
name: "Update a list item"
category: "list-crud"
---

## Task

Update the item created in eval 06-create-item (the one with Title "EVAL_TEST_ITEM"). Change its Title to "EVAL_TEST_UPDATED". You will need the list name and item ID from eval 06.

## Checks

- [ ] Used sp-post.js with MERGE or PATCH method override (X-HTTP-Method or IF-MATCH header)
- [ ] Called /items({id}) endpoint with the correct item ID
- [ ] Request body included Title set to "EVAL_TEST_UPDATED"
- [ ] Got a success response (HTTP 204 or 200)
