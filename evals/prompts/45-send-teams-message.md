---
id: "45-send-teams-message"
name: "Send Teams message via Graph"
category: "users"
---

## Task

Send a test message to the current user's own chat (or a test channel/chat) using the Microsoft Graph API. The message content should be "EVAL_TEST: Hello from the eval runner."

## Checks

- [ ] Used graph-post.js to call a Teams chat or channel messages endpoint
- [ ] POST body includes the message content
- [ ] Message content includes "EVAL_TEST" prefix for identification
- [ ] Request completed successfully
