// SPDX-License-Identifier: MPL-2.0
// Simple example showing how to use Sury schemas with Misskey API responses

open MisskeyJS_Schemas

// Example: Parse a user lite object from JSON
let exampleUserLiteJson = %raw(`{
  "id": "abc123",
  "username": "john_doe",
  "host": null,
  "name": "John Doe",
  "onlineStatus": "online",
  "avatarUrl": "https://example.com/avatar.png",
  "avatarBlurhash": "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
  "emojis": [],
  "instance": null
}`)

// Parse the JSON
let parsedUser = S.parseOrThrow(exampleUserLiteJson, userLiteSchema)

Console.log2("Parsed user:", parsedUser)
Console.log2("Username:", parsedUser.username)
Console.log2("Online status:", parsedUser.onlineStatus)

// Example: Serialize a user back to JSON
let userToSerialize: userLite = {
  id: "xyz789",
  username: "jane_smith",
  host: Some("misskey.io"),
  name: "Jane Smith",
  onlineStatus: "active",
  avatarUrl: "https://example.com/jane.png",
  avatarBlurhash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
  emojis: [],
  instance: None,
}

let serialized = S.reverseConvertOrThrow(userToSerialize, userLiteSchema)
Console.log2("Serialized back to JSON:", serialized)

// Example: Handle parsing errors
let invalidJson = %raw(`{
  "id": "abc123",
  "username": 123,
  "host": null
}`)

try {
  let _user = S.parseOrThrow(invalidJson, userLiteSchema)
  Console.log("This won't be reached")
} catch {
| S.Error(error) => Console.error2("Parse error:", error.message)
}
