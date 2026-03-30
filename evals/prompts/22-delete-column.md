---
id: "22-delete-column"
name: "Delete a column from a list"
category: "list-crud"
---

## Task

Delete the "EVAL_TEST_Column" column created in eval 21. After deleting, retrieve the list's fields and confirm the column is gone.

## Checks

- [ ] Used sp-post.js with X-HTTP-Method DELETE (or sp-delete.js) to remove the field
- [ ] Called /_api/web/lists/getByTitle('...')/fields/getByTitle('EVAL_TEST_Column')
- [ ] Verified the column no longer appears in the list's field collection
- [ ] No errors during deletion
