---
id: "14-graph-search"
name: "Search using Graph API"
category: "search"
---

## Task

Search for files across this SharePoint site using the Microsoft Graph Search API (`/v1.0/search/query`). Use a broad search term likely to return results (e.g., a common word or "*"). Display the names and paths of any matching files.

## Checks

- [ ] Used graph-post.js to make the API call
- [ ] Called /v1.0/search/query endpoint
- [ ] Request body includes a valid search request with entityTypes and query
- [ ] Response contains hitsContainers with results (or an empty set)
