---
id: "12-upload-file"
name: "Upload a file"
category: "files"
---

## Task

Upload a new text file named "eval-test-upload.txt" with the content "Hello from eval" to the default document library (e.g., "Shared Documents"). After uploading, confirm the file exists. Note: eval 13-delete-file will clean up this file.

## Checks

- [ ] Used sp-post.js with Files/add endpoint OR graph-post.js with PUT /content
- [ ] File name is "eval-test-upload.txt"
- [ ] File content is "Hello from eval"
- [ ] Got a success response confirming the file was created
