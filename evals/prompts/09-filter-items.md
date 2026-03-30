---
id: "09-filter-items"
name: "Filter/search list items"
category: "list-crud"
---

## Task

Find items in a list that match a specific condition. Use either the OData `$filter` query parameter (e.g., `$filter=Title eq 'some value'`) or a CAML query via the GetItems endpoint. Show the matching items.

## Checks

- [ ] Used sp-get.js with $filter parameter OR sp-post.js with CAML/GetItems
- [ ] Filter condition targets a specific field value
- [ ] Got a valid response with filtered results (or an empty set if no matches)
- [ ] Output shows only items matching the filter criteria
