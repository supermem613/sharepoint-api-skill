---
id: "21-add-column"
name: "Add a column to a list"
category: "list-crud"
---

## Task

Add a new single-line text column named "EVAL_TEST_Column" to the first non-hidden list on the site. After creating it, retrieve the list's fields and verify the new column appears in the schema.

## Checks

- [ ] Used sp-post.js to create the field via /_api/web/lists/getByTitle('...')/fields
- [ ] POST body includes Title "EVAL_TEST_Column" and FieldTypeKind for text (2)
- [ ] Verified the new column exists by retrieving the list's fields after creation
- [ ] Output shows the new column's Title, InternalName, and TypeAsString
