---
id: "40-delete-rule"
name: "Delete a list rule"
category: "advanced"
---

## Task

Delete the rule created in eval 39. After deleting, retrieve the list's rules and confirm the rule is gone.

## Checks

- [ ] Used sp-post.js with X-HTTP-Method DELETE to remove the rule
- [ ] Called the correct rule endpoint by rule ID
- [ ] Verified the rule no longer appears in the list's rules collection
- [ ] No errors during deletion
