---
id: "15-sp-search"
name: "Search using SP REST"
category: "search"
---

## Task

Search for content within this site using the SharePoint REST Search API (`/_api/search/query`). Use a broad query term likely to return results. Display the titles and paths of matching results.

## Checks

- [ ] Used sp-get.js to make the API call
- [ ] Called /_api/search/query with a querytext parameter
- [ ] Response contains PrimaryQueryResult or RelevantResults
- [ ] Output shows result titles or paths
