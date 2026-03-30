# SharePoint API Reference: Advanced Operations

Advanced SharePoint operations covering rules, workflows, recycle bin, approvals, navigation, quicksteps, eSignature, and document lifecycle management.

## Operations Covered

| Operation | Purpose | Primary API |
|-----------|---------|-------------|
| Get rules | List rules/automation on a list | SP REST |
| Create/update rule | Create or update a list rule | SP REST |
| Delete rule | Delete a list rule | SP REST |
| Get workflows | List Power Automate flows for a list | Power Automate / Graph |
| Create workflow | Create a Power Automate flow | Power Automate |
| Toggle workflow | Enable or disable a flow | Power Automate |
| Delete workflow | Delete a flow | Power Automate |
| Get recycle bin items | List recycle bin items | SP REST |
| Restore recycle bin items | Restore items from recycle bin | SP REST |
| Get restorable lists | List deleted lists eligible for restore | SP REST |
| Restore list | Restore a deleted list | SP REST |
| Configure approvals | Configure approval settings on a list | Power Automate |
| Get approval status | Check if approvals are enabled | SP REST |
| Get quicksteps | List quicksteps on a list | SP REST |
| Create/update quickstep | Create or update a quickstep | SP REST |
| Delete quickstep | Delete a quickstep | SP REST |
| List eSign requests | List eSignature requests | Graph |
| Create eSign request | Create an eSignature request | Graph |
| Get eSign agreement | Get eSignature agreement details | Graph |
| Cancel eSign agreement | Cancel an eSignature agreement | Graph |
| Retire documents | Retire documents (apply retention) | SP REST |
| Get retirable documents | Get documents eligible for retirement | SP REST |
| Filter retirable documents | Filter retirable documents | SP REST |
| Reorder navigation | Reorder site navigation nodes | SP REST |

---

## Recycle Bin

### Get recycle bin items

```bash
./sp-get.sh "/_api/web/recyclebin?\$select=Title,DirName,DeletedByEmail,DeletedDate,Id,ItemType&\$orderby=DeletedDate desc&\$top=50"
```

```powershell
$url = "$siteUrl/_api/web/recyclebin?`$select=Title,DirName,DeletedByEmail,DeletedDate,Id,ItemType&`$orderby=DeletedDate desc&`$top=50"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Restore items from recycle bin

```bash
./sp-post.sh "/_api/web/recyclebin/restorebyids" '{"ids":["guid1","guid2"]}'
```

```powershell
$url = "$siteUrl/_api/web/recyclebin/restorebyids"
$body = @{ ids = @("guid1", "guid2") } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Delete permanently from recycle bin

```bash
./sp-post.sh "/_api/web/recyclebin/deletebyids" '{"ids":["guid1"]}'
```

```powershell
$url = "$siteUrl/_api/web/recyclebin/deletebyids"
$body = @{ ids = @("guid1") } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Key notes

- Recycle bin items are retained for 93 days (first-stage) before moving to second-stage.
- `ItemType` distinguishes files, folders, and lists (`1` = File, `2` = Folder, `3` = List).
- Second-stage recycle bin: use `/_api/web/recyclebin/secondstagerecyclebin` for items deleted from first-stage.
- `restorebyids` and `deletebyids` accept an array of GUIDs for batch operations.

---

## Deleted Lists Recovery

### Get restorable lists (from recycle bin)

```bash
./sp-get.sh "/_api/web/recyclebin?\$filter=ItemType eq 3&\$select=Title,Id,DeletedDate,DeletedByEmail,DirName"
```

```powershell
$url = "$siteUrl/_api/web/recyclebin?`$filter=ItemType eq 3&`$select=Title,Id,DeletedDate,DeletedByEmail,DirName"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Restore a deleted list

```bash
./sp-post.sh "/_api/web/recyclebin('guid')/restore" ''
```

```powershell
$url = "$siteUrl/_api/web/recyclebin('$listRecycleBinId')/restore"
Invoke-RestMethod -Uri $url -Headers $headers -Method Post
```

### Key notes

- `ItemType eq 3` filters recycle bin to list items only.
- Restoring a list also restores its items, views, and metadata.
- If the original list URL is occupied (e.g., a new list with the same name was created), the restore may fail with a `409` conflict.

---

## Rules (SharePoint List Rules)

SharePoint list rules provide simple automation for email notifications and other actions triggered by list events.

### Get rules for a list

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/SPListRules"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/SPListRules"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Create a rule

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/SPListRules" '{
  "Title": "Notify on new items",
  "TriggerType": "ItemAdded",
  "ActionType": "EmailNotification",
  "Condition": "",
  "IsActive": true
}'
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/SPListRules"
$body = @{
    Title       = "Notify on new items"
    TriggerType = "ItemAdded"
    ActionType  = "EmailNotification"
    Condition   = ""
    IsActive    = $true
} | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Update a rule

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/SPListRules({ruleId})" '{
  "Title": "Updated rule name",
  "IsActive": false
}' PATCH
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/SPListRules($ruleId)"
$body = @{ Title = "Updated rule name"; IsActive = $false } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body -ContentType "application/json"
```

### Delete a rule

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/SPListRules({ruleId})" '' DELETE
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/SPListRules($ruleId)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
```

### Trigger types

| TriggerType | Description |
|-------------|-------------|
| `ItemAdded` | Fires when a new item is created |
| `ItemUpdated` | Fires when an item is modified |
| `ItemDeleted` | Fires when an item is deleted |

### Key notes

- Rules are a lightweight alternative to Power Automate flows for simple notifications.
- `Condition` uses a JSON-based filter format to scope which items trigger the rule.
- Rules are scoped per-list and require list owner permissions to create or modify.

---

## Power Automate Flows

Full Power Automate management requires the Power Automate Management API, which is beyond standard Graph/SP REST scope. Flow creation and management requires complex orchestration through the Power Automate service.

### List subscriptions (webhooks) associated with a list

```bash
./graph-get.sh "/v1.0/sites/{siteId}/lists/{listId}/subscriptions"
```

```powershell
$url = "https://graph.microsoft.com/v1.0/sites/$siteId/lists/$listId/subscriptions"
Invoke-RestMethod -Uri $url -Headers $graphHeaders -Method Get
```

### Key notes

- The Graph `subscriptions` endpoint shows webhook-based integrations, which Power Automate flows use under the hood.
- Creating, toggling, and deleting flows requires the Power Automate APIs (not standard Graph/SP REST).
- Flow management operations require complex orchestration through the Power Automate service.

---

## Approvals

Modern approvals in SharePoint are powered by Power Automate. Configuration is done through the SharePoint UI or Power Automate API, not directly through SP REST.

### Check if content approval is enabled on a list

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')?&\$select=EnableModeration,Title"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')?`$select=EnableModeration,Title"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Check for moderation status field

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/fields?\$filter=InternalName eq '_ModerationStatus'&\$select=Title,InternalName"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/fields?`$filter=InternalName eq '_ModerationStatus'&`$select=Title,InternalName"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Enable content approval on a list

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')" '{"EnableModeration": true}' PATCH
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')"
$body = @{ EnableModeration = $true } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body -ContentType "application/json"
```

### Key notes

- `EnableModeration` is the SP REST property that controls content approval.
- When enabled, items have a `_ModerationStatus` field: `0` = Approved, `1` = Denied, `2` = Pending.
- The `configure_approvals` operation orchestrates both the SP REST property and the Power Automate flow setup for modern approvals.

---

## Quicksteps

Quicksteps are pre-configured actions that list users can apply to items with a single click.

### Get quicksteps for a list

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/QuickSteps"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/QuickSteps"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Create or update a quickstep

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/QuickSteps" '{
  "Title": "Mark as Reviewed",
  "Actions": [
    {
      "FieldName": "Status",
      "Value": "Reviewed"
    }
  ]
}'
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/QuickSteps"
$body = @{
    Title   = "Mark as Reviewed"
    Actions = @(@{
        FieldName = "Status"
        Value     = "Reviewed"
    })
} | ConvertTo-Json -Depth 3
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Delete a quickstep

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/QuickSteps({quickstepId})" '' DELETE
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/QuickSteps($quickstepId)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
```

### Key notes

- Quicksteps batch one or more field-value updates into a single click action.
- They are scoped per-list and visible to all users with edit permissions.
- To update an existing quickstep, use `PATCH` with the quickstep ID.

---

## Navigation

### Get quick launch navigation nodes

```bash
./sp-get.sh "/_api/web/navigation/quicklaunch?\$select=Title,Url,Id,IsExternal"
```

```powershell
$url = "$siteUrl/_api/web/navigation/quicklaunch?`$select=Title,Url,Id,IsExternal"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Get top navigation bar nodes

```bash
./sp-get.sh "/_api/web/navigation/topnavigationbar?\$select=Title,Url,Id"
```

```powershell
$url = "$siteUrl/_api/web/navigation/topnavigationbar?`$select=Title,Url,Id"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Reorder navigation nodes

```bash
./sp-post.sh "/_api/web/navigation/quicklaunch({nodeId})/moveafterto({afterNodeId})" ''
```

```powershell
$url = "$siteUrl/_api/web/navigation/quicklaunch($nodeId)/moveafterto($afterNodeId)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Post
```

### Add a navigation node

```bash
./sp-post.sh "/_api/web/navigation/quicklaunch" '{
  "Title": "Team Wiki",
  "Url": "/sites/mysite/SitePages/Wiki.aspx",
  "IsExternal": false
}'
```

```powershell
$url = "$siteUrl/_api/web/navigation/quicklaunch"
$body = @{
    Title      = "Team Wiki"
    Url        = "/sites/mysite/SitePages/Wiki.aspx"
    IsExternal = $false
} | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Delete a navigation node

```bash
./sp-post.sh "/_api/web/navigation/quicklaunch({nodeId})" '' DELETE
```

```powershell
$url = "$siteUrl/_api/web/navigation/quicklaunch($nodeId)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Delete
```

### Key notes

- `quicklaunch` is the left-side navigation; `topnavigationbar` is the top navigation.
- `moveafterto` positions a node after the specified target node; use `0` as `afterNodeId` to move to the beginning.
- `IsExternal` should be `true` for links pointing outside the site collection.
- Navigation changes require site owner or site designer permissions.

---

## Site Features

### Get active site features

```bash
./sp-get.sh "/_api/web/features?\$select=DisplayName,DefinitionId"
```

```powershell
$url = "$siteUrl/_api/web/features?`$select=DisplayName,DefinitionId"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Activate a feature

```bash
./sp-post.sh "/_api/web/features/add('{featureGuid}',true)" ''
```

```powershell
$url = "$siteUrl/_api/web/features/add('$featureGuid',$true)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Post
```

### Deactivate a feature

```bash
./sp-post.sh "/_api/web/features/remove('{featureGuid}',true)" ''
```

```powershell
$url = "$siteUrl/_api/web/features/remove('$featureGuid',$true)"
Invoke-RestMethod -Uri $url -Headers $headers -Method Post
```

### Key notes

- The boolean parameter (`true`) in `add`/`remove` controls whether to force the operation.
- Feature activation/deactivation requires site collection administrator permissions.
- Some features have dependencies — deactivating a feature may fail if other features depend on it.

---

## Document Lifecycle / Retention

### Get compliance tag (retention label) on an item

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items({itemId})/ComplianceTag"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/items($itemId)/ComplianceTag"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Apply a retention label to an item

```bash
./sp-post.sh "/_api/web/lists(guid'{listId}')/items({itemId})/SetComplianceTag" '{
  "complianceTag": "RetentionLabel",
  "isTagPolicyHold": false,
  "isTagPolicyRecord": false
}'
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/items($itemId)/SetComplianceTag"
$body = @{
    complianceTag      = "RetentionLabel"
    isTagPolicyHold    = $false
    isTagPolicyRecord  = $false
} | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```

### Get retirable documents (items with retention labels nearing expiry)

```bash
./sp-get.sh "/_api/web/lists(guid'{listId}')/items?\$filter=OData__ComplianceTag ne null&\$select=Title,FileLeafRef,OData__ComplianceTag,OData__ComplianceTagWrittenTime"
```

```powershell
$url = "$siteUrl/_api/web/lists(guid'$listId')/items?`$filter=OData__ComplianceTag ne null&`$select=Title,FileLeafRef,OData__ComplianceTag,OData__ComplianceTagWrittenTime"
Invoke-RestMethod -Uri $url -Headers $headers -Method Get
```

### Key notes

- Retention labels must be published from the Microsoft Purview compliance portal before they can be applied.
- `isTagPolicyHold` locks the item so it cannot be deleted during the retention period.
- `isTagPolicyRecord` marks the item as a regulatory record (cannot be edited or deleted).
- Bulk document retirement operations require additional business logic for managing retention across many items at once.

---

## eSignature

SharePoint eSignature features are relatively new and use a combination of Graph API and SharePoint-specific endpoints. Some operations may be in preview.

### List eSign requests

```bash
./graph-get.sh "/v1.0/solutions/approval/operations?\$filter=requestType eq 'eSign'"
```

```powershell
$url = "https://graph.microsoft.com/v1.0/solutions/approval/operations?`$filter=requestType eq 'eSign'"
Invoke-RestMethod -Uri $url -Headers $graphHeaders -Method Get
```

### Get eSign agreement details

```bash
./graph-get.sh "/v1.0/solutions/approval/operations/{operationId}"
```

```powershell
$url = "https://graph.microsoft.com/v1.0/solutions/approval/operations/$operationId"
Invoke-RestMethod -Uri $url -Headers $graphHeaders -Method Get
```

### Cancel an eSign agreement

```bash
./graph-post.sh "/v1.0/solutions/approval/operations/{operationId}/cancel" ''
```

```powershell
$url = "https://graph.microsoft.com/v1.0/solutions/approval/operations/$operationId/cancel"
Invoke-RestMethod -Uri $url -Headers $graphHeaders -Method Post
```

### Key notes

- eSignature in SharePoint requires appropriate licensing and may require additional API permissions.
- The Graph eSignature APIs are partially in preview — endpoint paths and behavior may change.
- The eSignature operations wrap these APIs with additional validation and error handling.
- eSign requests are tied to specific documents in a document library.

---

## Common Patterns

### Error handling

All SP REST calls may return:
- `400` — malformed request (invalid rule condition, bad quickstep definition)
- `403` — insufficient permissions (most advanced operations require owner-level access)
- `404` — resource not found (deleted rule, missing list, expired recycle bin item)
- `409` — conflict (restoring a list when the URL is already occupied)

### Permission requirements

| Operation | Minimum Permission |
|-----------|-------------------|
| Recycle bin (view) | Site member |
| Recycle bin (restore/delete) | Site owner |
| Rules (CRUD) | List owner |
| Navigation (modify) | Site owner / Site designer |
| Features (activate/deactivate) | Site collection admin |
| Retention labels (apply) | Site member + compliance role |
| eSignature | Appropriate license + permissions |

### Batch operations

For operations that support batch processing (recycle bin restore/delete), pass multiple IDs in a single call to reduce round-trips:

```bash
# Restore multiple items at once
./sp-post.sh "/_api/web/recyclebin/restorebyids" '{"ids":["guid1","guid2","guid3"]}'
```

```powershell
$url = "$siteUrl/_api/web/recyclebin/restorebyids"
$body = @{ ids = @("guid1", "guid2", "guid3") } | ConvertTo-Json
Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body $body -ContentType "application/json"
```
