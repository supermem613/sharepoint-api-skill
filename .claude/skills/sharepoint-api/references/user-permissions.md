# User Info & Permissions

Reference for operations that resolve users and manage permissions.

## Operations Covered

| Operation | Purpose |
|-----------|---------|
| Get user info | Resolve user names, emails, and IDs |
| Check permissions | Check site and list permissions |

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/web/currentuser                                        # Current user
/_api/web/siteusers                                          # All site users
/_api/web/siteusers?$filter=Email eq '{email}'               # Resolve email to user ID
/_api/web/siteusers/getbyid({userId})                        # User by ID
/_api/web/roleassignments                                    # Permissions
```

---

## User Resolution

### Current User

```bash
# Get current user profile
node scripts/sp-get.js "/_api/web/currentuser?\$select=Id,Title,Email,LoginName,IsSiteAdmin"
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
node scripts/sp-get.js "/_api/web/siteusers?\$filter=PrincipalType eq 1&\$select=Id,Title,Email"
```


> **PrincipalType values:** 1 = User, 2 = Distribution List, 4 = Security Group, 8 = SharePoint Group

### Resolve Email → SharePoint User ID

```bash
# Needed when writing to Person fields — SP requires the numeric user ID
node scripts/sp-get.js "/_api/web/siteusers?\$filter=Email eq 'user@contoso.com'&\$select=Id"
```


### Get User by ID

```bash
node scripts/sp-get.js "/_api/web/siteusers/getbyid({userId})?\$select=Id,Title,Email"
```


---

## Site Permissions

### List Role Assignments

```bash
node scripts/sp-get.js "/_api/web/roleassignments?\$expand=Member,RoleDefinitionBindings&\$select=PrincipalId,Member/Title,RoleDefinitionBindings/Name"
```

    "$($_.Member.Title): $($_.RoleDefinitionBindings.results.Name -join ', ')"
}
```

### Check If Current User Has a Permission

```bash
# Full Control mask (High=2147483647, Low=4294967295)
node scripts/sp-get.js "/_api/web/doesuserhavePermissions(@v)?@v={'High':'2147483647','Low':'4294967295'}"
```


> **Common permission masks:**
> - Full Control: `High=2147483647, Low=4294967295`
> - Edit: `High=0, Low=1011030767`
> - View Only: `High=0, Low=138612833`

---

## Error Reference

| Status | Cause | Fix |
|--------|-------|-----|
| 400 | Invalid permission mask or malformed body | Verify JSON shape and parameter values |
| 403 | Insufficient permissions / sharing disabled by policy | Check tenant sharing settings and user role |
| 404 | User not found or item doesn't exist | Verify user email/ID and driveId/itemId |
| 409 | Sharing link already exists with different settings | Delete existing link first, or use the existing one |
| 429 | Throttled | Retry with exponential backoff |
