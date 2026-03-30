---
id: "20-caml-query"
name: "Generate and execute a CAML query"
category: "advanced"
---

## Task

Write a CAML query to find items from a list on this site. The query should filter items where a date field is within the last 30 days OR a text field matches a specific value. Execute the query using the GetItems endpoint (`/_api/web/lists/getbytitle('ListName')/GetItems`).

## Checks

- [ ] Generated valid CAML XML containing `<View>`, `<Query>`, and `<Where>` elements
- [ ] Used sp-post.js to POST to the GetItems endpoint
- [ ] Request body includes the CAML query in the correct format
- [ ] Got a valid response with matching items (or an empty set)
