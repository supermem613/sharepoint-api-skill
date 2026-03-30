---
id: "32-move-copy-file"
name: "Move or copy a file"
category: "files"
---

## Task

Upload a small test file "EVAL_TEST_MoveCopy.txt" to Shared Documents, then copy it into the "EVAL_TEST_Folder_Renamed" folder (or any subfolder). Verify the file exists in both locations (original + copy). Clean up both copies afterward.

## Checks

- [ ] Used sp-post.js to call copyto or moveto endpoint
- [ ] The file exists at the destination after the operation
- [ ] For copy: the original file still exists at the source
- [ ] Cleaned up test files after verification
