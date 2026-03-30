---
id: "39-create-rule"
name: "Create a list rule"
category: "advanced"
---

## Task

Create a rule on a list that sends a notification when a new item is created. Use the first non-hidden list on the site. Display the rule's Id and configuration after creation.

## Checks

- [ ] Used sp-post.js to create a rule via the list's rule endpoint
- [ ] POST body includes the rule condition and action (e.g., notify on item creation)
- [ ] Verified the rule was created by retrieving the list's rules
- [ ] Output shows the rule's Id and condition/action details
