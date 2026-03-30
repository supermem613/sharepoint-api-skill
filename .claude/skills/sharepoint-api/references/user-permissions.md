# User Info, Sharing & Permissions

Reference for operations that resolve users, share content, and send messages.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Get user info | Resolve user names, emails, and IDs |
| Share file | Share files/folders with people or via link |
| Send email | Send email via Microsoft Graph |
| Send Teams message | Send Teams chat message via Microsoft Graph |

---

## User Resolution

### Current User

```bash
# Get current user profile
./sp-get.sh "/_api/web/currentuser?\$select=Id,Title,Email,LoginName,IsSiteAdmin"
```

```powershell
# PowerShell equivalent
$response = Invoke-SpGet "/_api/web/currentuser?`$select=Id,Title,Email,LoginName,IsSiteAdmin"
$response.d
```

**Response shape:**
```json
{
  "d": {
    "Id": 42,
    "Title": "Jane Doe",
    "Email": "jane@contoso.com",
    "LoginName": "i:0#.f|membership|jane@contoso.com",
    "IsSiteAdmin": false
  }
}
```

### List Site Users (People Only)

```bash
# PrincipalType 1 = individual users (excludes groups, security groups)
./sp-get.sh "/_api/web/siteusers?\$filter=PrincipalType eq 1&\$select=Id,Title,Email"
```

```powershell
$users = Invoke-SpGet "/_api/web/siteusers?`$filter=PrincipalType eq 1&`$select=Id,Title,Email"
$users.d.results
```

> **PrincipalType values:** 1 = User, 2 = Distribution List, 4 = Security Group, 8 = SharePoint Group

### Search Users by Name (Graph)

```bash
# Requires ConsistencyLevel: eventual header (handled by helper)
./graph-get.sh "/v1.0/users?\$search=\"displayName:John\"&\$select=displayName,mail,id,jobTitle"
```

```powershell
$results = Invoke-GraphGet "/v1.0/users?`$search=`"displayName:John`"&`$select=displayName,mail,id,jobTitle"
$results.value
```

### Resolve Email → SharePoint User ID

```bash
# Needed when writing to Person fields — SP requires the numeric user ID
./sp-get.sh "/_api/web/siteusers?\$filter=Email eq 'user@contoso.com'&\$select=Id"
```

```powershell
$user = Invoke-SpGet "/_api/web/siteusers?`$filter=Email eq 'user@contoso.com'&`$select=Id"
$userId = $user.d.results[0].Id
```

### Get User by ID

```bash
./sp-get.sh "/_api/web/siteusers/getbyid({userId})?\$select=Id,Title,Email"
```

```powershell
$user = Invoke-SpGet "/_api/web/siteusers/getbyid($userId)?`$select=Id,Title,Email"
$user.d
```

---

## Sharing Files

### Create a Sharing Link (Graph)

```bash
./graph-post.sh "/v1.0/drives/{driveId}/items/{itemId}/createLink" '{
  "type": "view",
  "scope": "organization"
}'
```

```powershell
$body = @{
    type  = "view"
    scope = "organization"
} | ConvertTo-Json

Invoke-GraphPost "/v1.0/drives/$driveId/items/$itemId/createLink" $body
```

**Link type options:**

| `type` | Permission |
|--------|-----------|
| `view` | Read-only |
| `edit` | Read-write |
| `embed` | Embed in iframe |

**Scope options:**

| `scope` | Who can access |
|---------|---------------|
| `anonymous` | Anyone with the link (if tenant allows) |
| `organization` | Anyone in the org with the link |
| `users` | Only specified people |

### Share with Specific People (Graph)

```bash
./graph-post.sh "/v1.0/drives/{driveId}/items/{itemId}/invite" '{
  "recipients": [
    {"email": "user@contoso.com"}
  ],
  "roles": ["read"],
  "requireSignIn": true,
  "sendInvitation": true,
  "message": "Check out this document"
}'
```

```powershell
$body = @{
    recipients     = @(@{ email = "user@contoso.com" })
    roles          = @("read")
    requireSignIn  = $true
    sendInvitation = $true
    message        = "Check out this document"
} | ConvertTo-Json -Depth 3

Invoke-GraphPost "/v1.0/drives/$driveId/items/$itemId/invite" $body
```

**Role values:** `"read"`, `"write"`, `"owner"`

### Check Current Sharing Permissions

```bash
./graph-get.sh "/v1.0/drives/{driveId}/items/{itemId}/permissions"
```

```powershell
$perms = Invoke-GraphGet "/v1.0/drives/$driveId/items/$itemId/permissions"
$perms.value | ForEach-Object { "$($_.roles) — $($_.grantedToV2.user.displayName)" }
```

---

## Site Permissions

### List Role Assignments

```bash
./sp-get.sh "/_api/web/roleassignments?\$expand=Member,RoleDefinitionBindings&\$select=PrincipalId,Member/Title,RoleDefinitionBindings/Name"
```

```powershell
$roles = Invoke-SpGet "/_api/web/roleassignments?`$expand=Member,RoleDefinitionBindings&`$select=PrincipalId,Member/Title,RoleDefinitionBindings/Name"
$roles.d.results | ForEach-Object {
    "$($_.Member.Title): $($_.RoleDefinitionBindings.results.Name -join ', ')"
}
```

### Check If Current User Has a Permission

```bash
# Full Control mask (High=2147483647, Low=4294967295)
./sp-get.sh "/_api/web/doesuserhavePermissions(@v)?@v={'High':'2147483647','Low':'4294967295'}"
```

```powershell
$hasPermission = Invoke-SpGet "/_api/web/doesuserhavePermissions(@v)?@v={'High':'2147483647','Low':'4294967295'}"
$hasPermission.d.DoesUserHavePermissions
```

> **Common permission masks:**
> - Full Control: `High=2147483647, Low=4294967295`
> - Edit: `High=0, Low=1011030767`
> - View Only: `High=0, Low=138612833`

---

## Sending Email (Graph)

```bash
./graph-post.sh "/v1.0/me/sendMail" '{
  "message": {
    "subject": "Project Update",
    "body": {
      "contentType": "HTML",
      "content": "<p>Hello!</p>"
    },
    "toRecipients": [
      {"emailAddress": {"address": "user@contoso.com"}}
    ]
  }
}'
```

```powershell
$body = @{
    message = @{
        subject      = "Project Update"
        body         = @{ contentType = "HTML"; content = "<p>Hello!</p>" }
        toRecipients = @(
            @{ emailAddress = @{ address = "user@contoso.com" } }
        )
    }
} | ConvertTo-Json -Depth 5

Invoke-GraphPost "/v1.0/me/sendMail" $body
```

**Optional fields:**
- `ccRecipients` / `bccRecipients` — same shape as `toRecipients`
- `importance` — `"low"`, `"normal"`, `"high"`
- `attachments` — array of file attachments (base64-encoded)

> Returns **202 Accepted** with no body on success.

---

## Sending Teams Messages (Graph)

### Step 1 — Create a 1:1 Chat

```bash
./graph-post.sh "/v1.0/chats" '{
  "chatType": "oneOnOne",
  "members": [
    {
      "@odata.type": "#microsoft.graph.aadUserConversationMember",
      "roles": ["owner"],
      "user@odata.bind": "https://graph.microsoft.com/v1.0/users/{userId}"
    },
    {
      "@odata.type": "#microsoft.graph.aadUserConversationMember",
      "roles": ["owner"],
      "user@odata.bind": "https://graph.microsoft.com/v1.0/users/{recipientId}"
    }
  ]
}'
```

```powershell
$body = @{
    chatType = "oneOnOne"
    members  = @(
        @{
            "@odata.type"    = "#microsoft.graph.aadUserConversationMember"
            roles            = @("owner")
            "user@odata.bind" = "https://graph.microsoft.com/v1.0/users/$userId"
        },
        @{
            "@odata.type"    = "#microsoft.graph.aadUserConversationMember"
            roles            = @("owner")
            "user@odata.bind" = "https://graph.microsoft.com/v1.0/users/$recipientId"
        }
    )
} | ConvertTo-Json -Depth 4

$chat = Invoke-GraphPost "/v1.0/chats" $body
$chatId = $chat.id
```

> If the 1:1 chat already exists, the API returns the existing chat (idempotent).

### Step 2 — Send a Message

```bash
./graph-post.sh "/v1.0/chats/{chatId}/messages" '{
  "body": {
    "content": "Hello from the skill!"
  }
}'
```

```powershell
$body = @{
    body = @{ content = "Hello from the skill!" }
} | ConvertTo-Json -Depth 3

Invoke-GraphPost "/v1.0/chats/$chatId/messages" $body
```

**Optional message fields:**
- `body.contentType` — `"text"` (default) or `"html"`
- `mentions` — @mention users in the message
- `attachments` — attach cards or files

---

## Common Patterns

### Resolve User Then Share

A typical flow: look up a user by name, then share a file with them.

```bash
# 1. Find the user
./graph-get.sh "/v1.0/users?\$search=\"displayName:Jane\"&\$select=mail,id"

# 2. Share the file with their email
./graph-post.sh "/v1.0/drives/{driveId}/items/{itemId}/invite" '{
  "recipients": [{"email": "jane@contoso.com"}],
  "roles": ["read"],
  "sendInvitation": true,
  "message": "Here is the report you requested"
}'
```

### Resolve User Then Send Teams Message

```bash
# 1. Find recipient's Graph ID
./graph-get.sh "/v1.0/users?\$search=\"displayName:Jane\"&\$select=id"

# 2. Get current user ID
./graph-get.sh "/v1.0/me?\$select=id"

# 3. Create chat and send message
./graph-post.sh "/v1.0/chats" '{ ... }'
./graph-post.sh "/v1.0/chats/{chatId}/messages" '{ ... }'
```

---

## Error Reference

| Status | Cause | Fix |
|--------|-------|-----|
| 400 | Invalid permission mask or malformed body | Verify JSON shape and parameter values |
| 403 | Insufficient permissions / sharing disabled by policy | Check tenant sharing settings and user role |
| 404 | User not found or item doesn't exist | Verify user email/ID and driveId/itemId |
| 409 | Sharing link already exists with different settings | Delete existing link first, or use the existing one |
| 429 | Graph throttling | Retry with exponential backoff |
