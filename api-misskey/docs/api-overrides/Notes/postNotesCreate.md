---
endpoint: /notes/create
method: POST
hash: -bca53b
host: Misskey API
version: 2025.4.1-io.12b-fb6fbea074
operationId: post___notes___create
---

# notes/create

**Path**: `/notes/create`  
**Method**: `POST`  
**Operation**: `postNotesCreate`

## Default Description

notes/create

No description provided.

**Credential required**: *Yes* / **Permission**: *write:notes*

## Override

Add your custom documentation here. If this code block is empty, the default description will be used.

```
Create a new note (post) on Misskey.

This endpoint allows you to:
- Create text notes with markdown support
- Upload files/images  
- Set visibility (public, home, followers, specified)
- Add content warnings (CW)
- Create polls
- Reply to or quote other notes

**Important:** Requires the write:notes permission.

Example usage:
```rescript
let result = await postNotesCreate(
  {
    text: Some("Hello, Fediverse! 🎉"),
    visibility: Some("public"),
  },
  ~fetch
)
```
```
