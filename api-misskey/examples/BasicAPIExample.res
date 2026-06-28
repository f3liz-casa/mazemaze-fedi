// Example: Basic API usage with rescript-misskey (Unified API)
// 
// ⚠️ NOTE: This example uses the legacy MisskeyJS API.
// For new code, use the simpler Misskey API - see NewAPIExample.res or QuickStart.res
// 
// The legacy API still works and is maintained for compatibility.

open MisskeyJS

// Create a unified client
let client = Client.make(~origin="https://misskey.example", ~credential="your-token", ())

// Get server metadata (via API submodule for less-common operations)
// DISABLED: API module needs refactoring
// let getMeta = async () => {
//   let result = await client->API.Meta.get(~detail=true, ())
//   switch result {
//   | Ok(meta) => Console.log2("Server meta:", meta)
//   | Error(#APIError(err)) => Console.log2("API Error:", err.message)
//   | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
//   }
// }

// Get current user info (via Me module - major API)
// DISABLED: Me module needs refactoring
// let getCurrentUser = async () => {
//   let result = await client->Me.get
//   switch result {
//   | Ok(user) => Console.log2("Current user:", user)
//   | Error(#APIError(err)) => Console.log2("API Error:", err.message)
//   | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
//   }
// }

// Create a note (via Notes module - major API)
let createNote = async (~text: string) => {
  let result = await client->Notes.create(~text, ~visibility=#public, ())

  switch result {
  | Ok(response) => Console.log2("Note created:", response)
  | Error(#APIError(err)) => Console.log2("Failed to create note:", err.message)
  | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
  }
}

// Get home timeline (via Timeline module - major API)
let getTimeline = async () => {
  let result = await client->Timeline.fetch(
    ~type_=#home,
    ~params={
      limit: 20,
      withRenotes: true,
    },
    (),
  )

  switch result {
  | Ok(notes) => {
      Console.log2("Timeline notes:", notes->Array.length)
      notes->Array.forEach(note => {
        Console.log(note)
      })
    }
  | Error(#APIError(err)) => Console.log2("API Error:", err.message)
  | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
  }
}

// React to a note (via Notes module)
let reactToNote = async (~noteId: string, ~reaction: string) => {
  let result = await client->Notes.react(~noteId, ~reaction)

  switch result {
  | Ok(_) => Console.log("Reaction added!")
  | Error(#APIError(err)) => Console.log2("Failed to react:", err.message)
  | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
  }
}

// Follow a user (via API.Following - less common operation)
// DISABLED: API module needs refactoring
// let followUser = async (~userId: string) => {
//   let result = await client->API.Following.create(~userId)
//
//   switch result {
//   | Ok(_) => Console.log("User followed!")
//   | Error(#APIError(err)) => Console.log2("Failed to follow:", err.message)
//   | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
//   }
// }

// Get notifications (via Notifications module - major API)
let getNotifications = async () => {
  let result = await client->Notifications.fetch(
    ~params={
      limit: 10,
      markAsRead: true,
    },
    (),
  )

  switch result {
  | Ok(notifications) => {
      Console.log2("Notifications:", notifications->Array.length)
      notifications->Array.forEach(notif => {
        Console.log(notif)
      })
    }
  | Error(#APIError(err)) => Console.log2("API Error:", err.message)
  | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
  }
}

// Update profile (via Me module)
// DISABLED: Me module needs refactoring
// let updateProfile = async () => {
//   let result = await client->Me.update(~name="My New Name", ~description="Hello from ReScript!", ())
//
//   switch result {
//   | Ok(user) => Console.log2("Profile updated:", user)
//   | Error(#APIError(err)) => Console.log2("Failed to update:", err.message)
//   | Error(#UnknownError(err)) => Console.log2("Unknown Error:", err)
//   }
// }

// Main function
let main = async () => {
  Console.log("=== Misskey API Examples ===\n")

  // Get server info
  // await getMeta()

  // Get current user
  // await getCurrentUser()

  // Get timeline
  await getTimeline()

  // Create a note
  await createNote(~text="Hello from rescript-misskey!")

  // Get notifications
  await getNotifications()
}

// Run examples
// Uncomment to run:
// main()->ignore
