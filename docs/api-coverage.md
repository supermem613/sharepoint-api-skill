# API Coverage

Complete reference of SharePoint operations supported by this skill.

---

## List Operations

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Get list items | SP REST | GET | `/_api/web/lists(guid'{id}')/items` | list-operations.md |
| Get single item by ID | SP REST | GET | `/_api/web/lists(guid'{id}')/items({itemId})` | list-operations.md |
| Get item metadata (expanded) | SP REST | GET | `/_api/web/lists(guid'{id}')/items({itemId})?$expand=Author,Editor` | list-operations.md |
| Create list item | SP REST | POST | `/_api/web/lists(guid'{id}')/items` | list-operations.md |
| Update list item | SP REST | PATCH | `/_api/web/lists(guid'{id}')/items({itemId})` | list-operations.md |
| Batch update items | SP REST | POST | `/_api/$batch` | list-operations.md |
| Delete list item | SP REST | DELETE | `/_api/web/lists(guid'{id}')/items({itemId})` | list-operations.md |
| Recycle list item | SP REST | POST | `/_api/web/lists(guid'{id}')/items({itemId})/recycle` | list-operations.md |
| Search/filter items (OData) | SP REST | GET | `/_api/web/lists(guid'{id}')/items?$filter=...` | list-operations.md |
| Search/filter items (CAML) | SP REST | POST | `/_api/web/lists(guid'{id}')/GetItems` | list-operations.md |
| Get item version history | SP REST | GET | `/_api/web/lists(guid'{id}')/items({itemId})/versions` | list-operations.md |
| Restore item version | SP REST | POST | `/_api/web/lists(guid'{id}')/items({itemId})/versions({vId})/restoreByLabel` | list-operations.md |
| Create list | SP REST | POST | `/_api/web/lists` | list-operations.md |
| Update list properties | SP REST | PATCH | `/_api/web/lists(guid'{id}')` | list-operations.md |
| Delete list | SP REST | DELETE | `/_api/web/lists(guid'{id}')` | list-operations.md |

## List Schema & Views

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Get all columns | SP REST | GET | `/_api/web/lists(guid'{id}')/fields` | site-discovery.md |
| Add a column | SP REST | POST | `/_api/web/lists(guid'{id}')/fields` | list-operations.md |
| Delete a column | SP REST | DELETE | `/_api/web/lists(guid'{id}')/fields('{fieldId}')` | list-operations.md |
| Get views | SP REST | GET | `/_api/web/lists(guid'{id}')/views` | list-operations.md |
| Get view definition | SP REST | GET | `/_api/web/lists(guid'{id}')/views(guid'{viewId}')` | list-operations.md |
| Create a view | SP REST | POST | `/_api/web/lists(guid'{id}')/views` | list-operations.md |
| Update a view | SP REST | PATCH | `/_api/web/lists(guid'{id}')/views(guid'{viewId}')` | list-operations.md |
| Delete a view | SP REST | DELETE | `/_api/web/lists(guid'{id}')/views(guid'{viewId}')` | list-operations.md |
| Apply view formatting (XML) | SP REST | POST | `/_api/web/lists(guid'{id}')/views(guid'{viewId}')/SetViewXml` | list-operations.md |
| Apply column formatting (JSON) | SP REST | PATCH | `/_api/web/lists(guid'{id}')/fields('{fieldId}')` (CustomFormatter) | list-operations.md |
| Get content types | SP REST | GET | `/_api/web/lists(guid'{id}')/contenttypes` | site-discovery.md |

## File & Folder Operations

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Read file content | SP REST | GET | `/_api/web/getfilebyserverrelativeurl('{path}')/$value` | file-operations.md |
| Upload file (< 4 MB) | SP REST | POST | `/_api/.../Files/add(url='{name}',overwrite=true)` | file-operations.md |
| Create folder | SP REST | POST | `/_api/web/folders` | file-operations.md |
| List folder contents (files) | SP REST | GET | `/_api/web/getfolderbyserverrelativeurl('{path}')/Files` | file-operations.md |
| List folder contents (subfolders) | SP REST | GET | `/_api/web/getfolderbyserverrelativeurl('{path}')/Folders` | file-operations.md |
| Rename file/folder | SP REST | PATCH | `/_api/web/getfilebyserverrelativeurl('{path}')` | file-operations.md |
| Move file | SP REST | POST | `/_api/web/getfilebyserverrelativeurl('{path}')/moveto(...)` | file-operations.md |
| Copy file | SP REST | POST | `/_api/web/getfilebyserverrelativeurl('{path}')/copyto(...)` | file-operations.md |
| Delete file (recycle) | SP REST | POST | `/_api/web/getfilebyserverrelativeurl('{path}')/recycle` | file-operations.md |
| Delete file (permanent) | SP REST | DELETE | `/_api/web/getfilebyserverrelativeurl('{path}')` | file-operations.md |
| Get file versions | SP REST | GET | `/_api/web/lists(guid'{id}')/items({itemId})/versions` | file-operations.md |
| Set folder color | SP REST | PATCH | `/_api/web/getfolderbyserverrelativeurl('{path}')/ListItemAllFields` | file-operations.md |

## Search

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Site-scoped search | SP REST | GET | `/_api/search/query?querytext='{query}'` | search.md |
| Search with refiners | SP REST | GET | `/_api/search/query?querytext='{query}'&refiners='{refiners}'` | search.md |

## Site Discovery

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Get site info | SP REST | GET | `/_api/web?$select=Title,Url,Description` | site-discovery.md |
| Get site collection info | SP REST | GET | `/_api/site?$select=Id,Url` | site-discovery.md |
| Discover lists/libraries | SP REST | GET | `/_api/web/lists?$filter=Hidden eq false` | site-discovery.md |
| Get list schema | SP REST | GET | `/_api/web/lists(guid'{id}')/fields?$filter=Hidden eq false` | site-discovery.md |
| Get list by URL | SP REST | GET | `/_api/web/GetList('{serverRelativeUrl}')` | site-discovery.md |
| Get regional settings | SP REST | GET | `/_api/web/regionalsettings` | site-discovery.md |
| Get content types | SP REST | GET | `/_api/web/contenttypes` | site-discovery.md |

## Pages

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| List site pages | SP REST | GET | `/_api/web/lists/getbytitle('Site Pages')/items` | page-operations.md |
| Get page content | SP REST | GET | `/_api/sitepages/pages({pageId})` | page-operations.md |
| Read page as HTML | SP REST | GET | `/_api/web/getfilebyserverrelativeurl('{path}')/$value` | page-operations.md |
| Create page | SP REST | POST | `/_api/sitepages/pages` | page-operations.md |
| Create news post | SP REST | POST | `/_api/sitepages/pages` (PromotedState: 2) | page-operations.md |
| Update page content | SP REST | PATCH | `/_api/sitepages/pages({pageId})` | page-operations.md |
| Set canvas content | SP REST | POST | `/_api/sitepages/pages({pageId})/savepage` | page-operations.md |
| Publish page | SP REST | POST | `/_api/sitepages/pages({pageId})/publish` | page-operations.md |
| Delete page | SP REST | DELETE | `/_api/web/getfilebyserverrelativeurl('{path}')` | page-operations.md |

## Users & Permissions

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Get current user | SP REST | GET | `/_api/web/currentuser` | user-permissions.md |
| List site users | SP REST | GET | `/_api/web/siteusers?$filter=PrincipalType eq 1` | user-permissions.md |
| Resolve user by email | SP REST | GET | `/_api/web/siteusers?$filter=Email eq '{email}'` | user-permissions.md |
| Get user by ID | SP REST | GET | `/_api/web/siteusers/getbyid({userId})` | user-permissions.md |
| List role assignments | SP REST | GET | `/_api/web/roleassignments?$expand=Member,RoleDefinitionBindings` | user-permissions.md |
| Check user permission | SP REST | GET | `/_api/web/doesuserhavePermissions(...)` | user-permissions.md |

## Communication

Not supported. Email sending, Teams messaging, and sharing links require the Microsoft Graph API, which this skill does not use.

## Advanced Operations

| Operation | API | Method | Endpoint | Reference |
|-----------|-----|--------|----------|-----------|
| Get recycle bin items | SP REST | GET | `/_api/web/recyclebin` | advanced-operations.md |
| Restore from recycle bin | SP REST | POST | `/_api/web/recyclebin/restorebyids` | advanced-operations.md |
| Delete from recycle bin | SP REST | POST | `/_api/web/recyclebin/deletebyids` | advanced-operations.md |
| Get deleted lists | SP REST | GET | `/_api/web/recyclebin?$filter=ItemType eq 3` | advanced-operations.md |
| Restore deleted list | SP REST | POST | `/_api/web/recyclebin('{id}')/restore` | advanced-operations.md |
| Get quicksteps | SP REST | GET | `/_api/web/lists(guid'{id}')/QuickSteps` | advanced-operations.md |
| Create/update quickstep | SP REST | POST/PATCH | `/_api/web/lists(guid'{id}')/QuickSteps` | advanced-operations.md |
| Delete quickstep | SP REST | DELETE | `/_api/web/lists(guid'{id}')/QuickSteps('{stepId}')` | advanced-operations.md |
| Get navigation nodes | SP REST | GET | `/_api/web/navigation/quicklaunch` | advanced-operations.md |
| Add/reorder navigation | SP REST | POST | `/_api/web/navigation/quicklaunch` | advanced-operations.md |
| Get/toggle site features | SP REST | POST | `/_api/web/features/add('{featureGuid}',true)` | advanced-operations.md |
| Get retention label | SP REST | GET | `/_api/web/lists(guid'{id}')/items({itemId})/ComplianceTag` | advanced-operations.md |
| Apply retention label | SP REST | POST | `/_api/web/lists(guid'{id}')/items({itemId})/SetComplianceTag` | advanced-operations.md |
| List eSign requests | SP REST | GET | `/_api/web/lists(guid'{id}')/items?$filter=...` | advanced-operations.md |
| Configure approvals | SP REST | PATCH | `/_api/web/lists(guid'{id}')` (EnableModeration) | advanced-operations.md |
| List webhooks/subscriptions | SP REST | GET | `/_api/web/lists(guid'{id}')/subscriptions` | advanced-operations.md |

## Not Supported

| Operation | Why | Workaround |
|-----------|-----|-----------|
| Email sending | No SP REST equivalent | Use Outlook or other email tools |
| Teams messaging | No SP REST equivalent | Use Teams directly |
| Sharing links | No SP REST equivalent | Share via SharePoint UI |
| Enterprise-wide search (across all M365) | SP REST search is site-scoped only | Use SharePoint admin or M365 tools |
| Enterprise RAG grounding | Requires proprietary backend | Agent reads files + reasons directly |
| UI-only operations (navigate, preview) | No browser at runtime | Not needed for CLI agents |
| Server-side code execution | Sandboxed environment | Agent runs code locally |
| NL-to-CAML generation | Redundant — the agent IS an LLM | Generate CAML directly using patterns in `api-patterns.md` |
| Full Power Automate management | Requires Power Automate Management API | Use PA Management API for flow operations |
