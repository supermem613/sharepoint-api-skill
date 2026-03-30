---
id: "44-send-email"
name: "Send email via Graph"
category: "users"
---

## Task

Send a test email to the current user using the Microsoft Graph API. The email subject should be "EVAL_TEST_Email" and the body should be "This is a test email from the eval runner."

## Checks

- [ ] Used graph-post.js to call /me/sendMail
- [ ] POST body includes message with subject, body, and toRecipients
- [ ] Subject is "EVAL_TEST_Email"
- [ ] Request completed successfully (HTTP 202 or equivalent)
