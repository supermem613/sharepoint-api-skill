---
id: "27-delete-list"
name: "Delete a list"
category: "list-crud"
---

## Task

Delete the "EVAL_TEST_LIST" created in eval 26. After deleting, confirm the list no longer exists on the site.

## Checks

- [ ] Used sp-post.js with X-HTTP-Method DELETE to remove the list
- [ ] Called /_api/web/lists/getByTitle('EVAL_TEST_LIST')
- [ ] Verified the list no longer appears in the site's lists collection
- [ ] No errors during deletion
