---
id: "02-discover-lists"
name: "List all lists and libraries"
category: "discovery"
---

## Task

Show all non-hidden lists and libraries on this SharePoint site. For each list, display its Title and ItemCount. Exclude hidden lists from the output.

## Checks

- [ ] Used sp-get.js to make the API call
- [ ] Called /_api/web/lists with $filter=Hidden eq false (or equivalent)
- [ ] Output includes list/library names (Title)
- [ ] Output includes ItemCount for each list
