# SharePoint API Reference: Advanced Operations

Advanced SharePoint operations covering rules, workflows, recycle bin, approvals, navigation, quicksteps, eSignature, and document lifecycle management.

## Operations Covered

| Operation | Purpose | Primary API |
|-----------|---------|-------------|
| Get rules | List rules/automation on a list | SP REST |
| Create/update rule | Create or update a list rule | SP REST |
| Delete rule | Delete a list rule | SP REST |
| Get workflows | List Power Automate flows for a list | Power Automate |
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
| List eSign requests | List eSignature requests | SP REST (preview) |
| Create eSign request | Create an eSignature request | SP REST (preview) |
| Get eSign agreement | Get eSignature agreement details | SP REST (preview) |
| Cancel eSign agreement | Cancel an eSignature agreement | SP REST (preview) |
| Retire documents | Retire documents (apply retention) | SP REST |
| Get retirable documents | Get documents eligible for retirement | SP REST |
| Filter retirable documents | Filter retirable documents | SP REST |
| Reorder navigation | Reorder site navigation nodes | SP REST |

## Valid Endpoints

**Only use these patterns.** Replace `{placeholders}` with real values.

```
/_api/web/recyclebin                                         # Recycle bin items
/_api/web/recyclebin/restorebyids                            # Restore items (POST)
/_api/web/recyclebin/deletebyids                             # Permanent delete (POST)
/_api/web/lists(guid'{listId}')/SPListRules                  # List rules (GET/POST)
/_api/web/lists(guid'{listId}')/SPListRules({ruleId})        # Single rule (DELETE)
/_api/web/navigation/quicklaunch                             # Quick launch nav
/_api/web/navigation/topnavigationbar                        # Top nav
/_api/web/features                                           # Site features
/_api/web/features/add('{featureGuid}',true)                 # Activate feature (POST)
/_api/web/features/remove('{featureGuid}',true)              # Deactivate feature (POST)
```

---

## Recycle Bin

### Get recycle bin items

```
node scripts/sp-get.js "/_api/web/recyclebin?\$select=Title,DirName,DeletedByEmail,DeletedDate,Id,ItemType&\$orderby=DeletedDate desc&\$top=50"
```


### Restore items from recycle bin

```
node scripts/sp-post.js "/_api/web/recyclebin/restorebyids" '{"ids":["guid1","guid2"]}'
```


### Delete permanently from recycle bin

```
node scripts/sp-post.js "/_api/web/recyclebin/deletebyids" '{"ids":["guid1"]}'
```


### Key notes

- Recycle bin items are retained for 93 days (first-stage) before moving to second-stage.
- `ItemType` distinguishes files, folders, and lists (`1` = File, `2` = Folder, `3` = List).
- Second-stage recycle bin: use `/_api/web/recyclebin/secondstagerecyclebin` for items deleted from first-stage.
- `restorebyids` and `deletebyids` accept an array of GUIDs for batch operations.

---

## Deleted Lists Recovery

### Get restorable lists (from recycle bin)

```
node scripts/sp-get.js "/_api/web/recyclebin?\$filter=ItemType eq 3&\$select=Title,Id,DeletedDate,DeletedByEmail,DirName"
```


### Restore a deleted list

```
node scripts/sp-post.js "/_api/web/recyclebin('guid')/restore" ''
```


### Key notes

- `ItemType eq 3` filters recycle bin to list items only.
- Restoring a list also restores its items, views, and metadata.
- If the original list URL is occupied (e.g., a new list with the same name was created), the restore may fail with a `409` conflict.

---

## Rules (SharePoint List Rules)

SharePoint list rules provide simple automation for email notifications and other actions triggered by list events.

### Get rules for a list

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/SPListRules"
```


### Create a rule

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/SPListRules" '{
  "Title": "Notify on new items",
  "TriggerType": "ItemAdded",
  "ActionType": "EmailNotification",
  "Condition": "",
  "IsActive": true
}'
```


### Update a rule

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/SPListRules({ruleId})" '{
  "Title": "Updated rule name",
  "IsActive": false
}' PATCH
```


### Delete a rule

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/SPListRules({ruleId})" '' DELETE
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

Full Power Automate management requires the Power Automate Management API, which is beyond standard SP REST scope. Flow creation and management requires complex orchestration through the Power Automate service.

### List subscriptions (webhooks) associated with a list

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/subscriptions"
```


### Key notes

- The `subscriptions` endpoint shows webhook-based integrations, which Power Automate flows use under the hood.
- Creating, toggling, and deleting flows requires the Power Automate APIs (not standard SP REST).
- Flow management operations require complex orchestration through the Power Automate service.

---

## Approvals

Modern approvals in SharePoint are powered by Power Automate. Configuration is done through the SharePoint UI or Power Automate API, not directly through SP REST.

### Check if content approval is enabled on a list

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')?&\$select=EnableModeration,Title"
```


### Check for moderation status field

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/fields?\$filter=InternalName eq '_ModerationStatus'&\$select=Title,InternalName"
```


### Enable content approval on a list

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')" '{"EnableModeration": true}' PATCH
```


### Key notes

- `EnableModeration` is the SP REST property that controls content approval.
- When enabled, items have a `_ModerationStatus` field: `0` = Approved, `1` = Denied, `2` = Pending.
- The `configure_approvals` operation orchestrates both the SP REST property and the Power Automate flow setup for modern approvals.

---

## Quicksteps

Quicksteps are pre-configured actions that list users can apply to items with a single click.

### Get quicksteps for a list

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/QuickSteps"
```


### Create or update a quickstep

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/QuickSteps" '{
  "Title": "Mark as Reviewed",
  "Actions": [
    {
      "FieldName": "Status",
      "Value": "Reviewed"
    }
  ]
}'
```


### Delete a quickstep

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/QuickSteps({quickstepId})" '' DELETE
```


### Key notes

- Quicksteps batch one or more field-value updates into a single click action.
- They are scoped per-list and visible to all users with edit permissions.
- To update an existing quickstep, use `PATCH` with the quickstep ID.

---

## Navigation

### Get quick launch navigation nodes

```
node scripts/sp-get.js "/_api/web/navigation/quicklaunch?\$select=Title,Url,Id,IsExternal"
```


### Get top navigation bar nodes

```
node scripts/sp-get.js "/_api/web/navigation/topnavigationbar?\$select=Title,Url,Id"
```


### Reorder navigation nodes

```
node scripts/sp-post.js "/_api/web/navigation/quicklaunch({nodeId})/moveafterto({afterNodeId})" ''
```


### Add a navigation node

```
node scripts/sp-post.js "/_api/web/navigation/quicklaunch" '{
  "Title": "Team Wiki",
  "Url": "/sites/mysite/SitePages/Wiki.aspx",
  "IsExternal": false
}'
```


### Delete a navigation node

```
node scripts/sp-post.js "/_api/web/navigation/quicklaunch({nodeId})" '' DELETE
```


### Key notes

- `quicklaunch` is the left-side navigation; `topnavigationbar` is the top navigation.
- `moveafterto` positions a node after the specified target node; use `0` as `afterNodeId` to move to the beginning.
- `IsExternal` should be `true` for links pointing outside the site collection.
- Navigation changes require site owner or site designer permissions.

---

## Site Features

### Get active site features

```
node scripts/sp-get.js "/_api/web/features?\$select=DisplayName,DefinitionId"
```


### Activate a feature

```
node scripts/sp-post.js "/_api/web/features/add('{featureGuid}',true)" ''
```


### Deactivate a feature

```
node scripts/sp-post.js "/_api/web/features/remove('{featureGuid}',true)" ''
```


### Key notes

- The boolean parameter (`true`) in `add`/`remove` controls whether to force the operation.
- Feature activation/deactivation requires site collection administrator permissions.
- Some features have dependencies — deactivating a feature may fail if other features depend on it.

---

## Document Lifecycle / Retention

### Get compliance tag (retention label) on an item

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/items({itemId})/ComplianceTag"
```


### Apply a retention label to an item

```
node scripts/sp-post.js "/_api/web/lists(guid'{listId}')/items({itemId})/SetComplianceTag" '{
  "complianceTag": "RetentionLabel",
  "isTagPolicyHold": false,
  "isTagPolicyRecord": false
}'
```


### Get retirable documents (items with retention labels nearing expiry)

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/items?\$filter=OData__ComplianceTag ne null&\$select=Title,FileLeafRef,OData__ComplianceTag,OData__ComplianceTagWrittenTime"
```


### Key notes

- Retention labels must be published from the Microsoft Purview compliance portal before they can be applied.
- `isTagPolicyHold` locks the item so it cannot be deleted during the retention period.
- `isTagPolicyRecord` marks the item as a regulatory record (cannot be edited or deleted).
- Bulk document retirement operations require additional business logic for managing retention across many items at once.

---

## eSignature

SharePoint eSignature features are relatively new and may use preview endpoints. Some operations may not be available in all environments.

### List eSign requests

```
node scripts/sp-get.js "/_api/web/lists(guid'{listId}')/items?\$filter=ContentTypeId eq '0x010100...eSign'&\$select=Title,Id"
```

> **Note:** eSignature APIs are in preview and may require specific endpoint patterns depending on your environment.

### Key notes

- eSignature in SharePoint requires appropriate licensing and may require additional permissions.
- The eSignature APIs are partially in preview — endpoint paths and behavior may change.
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

```
# Restore multiple items at once
node scripts/sp-post.js "/_api/web/recyclebin/restorebyids" '{"ids":["guid1","guid2","guid3"]}'
```

