---
id: "23-create-view"
name: "Create a list view"
category: "list-crud"
---

## Task

Create a new view named "EVAL_TEST_View" on the first non-hidden list. The view should include only the Title and Created fields. After creation, retrieve the view and display its properties.

## Checks

- [ ] Used sp-post.js to POST to /_api/web/lists/getByTitle('...')/views
- [ ] POST body includes Title "EVAL_TEST_View" and ViewFields
- [ ] Verified the view was created by retrieving it from the views collection
- [ ] Output shows the view's Title and ViewFields
