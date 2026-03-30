---
id: "29-apply-column-formatting"
name: "Apply column formatting"
category: "list-crud"
---

## Task

Apply JSON column formatting to the Title field of a list. Use a simple formatter that makes the text bold (e.g., `{"elmType":"div","txtContent":"@currentField","style":{"font-weight":"bold"}}`). After applying, retrieve the field's CustomFormatter property to verify.

## Checks

- [ ] Used sp-post.js to update the field with CustomFormatter JSON
- [ ] Called the field endpoint with MERGE/PATCH and included CustomFormatter in the body
- [ ] Retrieved the field after update and confirmed CustomFormatter is set
- [ ] The formatter JSON is valid and parseable
