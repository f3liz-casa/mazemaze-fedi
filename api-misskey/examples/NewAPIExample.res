// NewAPIExample.res - Demonstrating the clean Misskey API
//
// The new API is designed to be discoverable through autocompletion.
// Just start typing and your editor will guide you!

// ============================================================================
// Getting Started - Ultra Simple!
// ============================================================================

// Connect to a public instance
let publicClient = Misskey.connect("https://misskey.io")

// Connect with authentication
let myClient = Misskey.connect("https://misskey.io", ~token="your-token-here")

// ============================================================================
// Post Notes - Clean and simple
// ============================================================================

let postSimpleNote = async () => {
  // Most common case - just post text
  let result = await myClient->Misskey.Notes.create("Hello, Misskey! 🎉", ())
  
  switch result {
  | Ok(note) => {
      Console.log("✓ Posted!")
      Console.log(note)
    }
  | Error(msg) => Console.error(`✗ Failed: ${msg}`)
  }
}

let postWithOptions = async () => {
  // With visibility and content warning
  let result = await myClient->Misskey.Notes.create(
    "This is a followers-only post",
    ~visibility=#followers,
    ~cw="CW: personal thoughts",
    (),
  )
  
  switch result {
  | Ok(note) => Console.log("✓ Posted privately!")
  | Error(msg) => Console.error(`✗ Failed: ${msg}`)
  }
}

let replyToNote = async () => {
  // Reply to a note
  let result = await myClient->Misskey.Notes.create(
    "Great post!",
    ~replyId="note-id-here",
    (),
  )
}

// ============================================================================
// Read Timelines - Just as simple
// ============================================================================

let getHomeTimeline = async () => {
  let result = await myClient->Misskey.Notes.timeline(#home, ~limit=20, ())
  
  switch result {
  | Ok(notes) => {
      Console.log("Got timeline!")
      Console.log(notes)
    }
  | Error(msg) => Console.error(`Failed: ${msg}`)
  }
}

let getLocalTimeline = async () => {
  // Get local timeline
  let result = await myClient->Misskey.Notes.timeline(#local, ())
  
  switch result {
  | Ok(notes) => {
      Console.log("Local timeline:")
      Console.log(notes)
    }
  | Error(_) => Console.error("Failed to get local timeline")
  }
}

// ============================================================================
// Real-time Streaming - Set it and forget it!
// ============================================================================

let streamHomeTimeline = () => {
  // Listen for connection events (optional)
  myClient->Misskey.Stream.onConnected(() => {
    Console.log("🟢 Connected to stream!")
  })
  
  myClient->Misskey.Stream.onDisconnected(() => {
    Console.log("🔴 Disconnected from stream")
  })
  
  // Subscribe to timeline - one line!
  let subscription = myClient->Misskey.Stream.timeline(#home, note => {
    Console.log("📝 New note in home timeline!")
    Console.log(note)
  })
  
  // Return cleanup function
  () => subscription.dispose()
}

let streamNotifications = () => {
  // Subscribe to notifications - super simple!
  let subscription = myClient->Misskey.Stream.notifications(notif => {
    Console.log("🔔 New notification!")
    Console.log(notif)
  })
  
  // Cleanup
  () => subscription.dispose()
}

let streamMultipleTimelines = () => {
  // You can have multiple subscriptions
  let homeSub = myClient->Misskey.Stream.timeline(#home, note => {
    Console.log2("🏠 Home:", note)
  })
  
  let localSub = myClient->Misskey.Stream.timeline(#local, note => {
    Console.log2("🏘️ Local:", note)
  })
  
  let globalSub = myClient->Misskey.Stream.timeline(#global, note => {
    Console.log2("🌐 Global:", note)
  })
  
  // Cleanup all
  () => {
    homeSub.dispose()
    localSub.dispose()
    globalSub.dispose()
    Misskey.Stream.close(myClient)
  }
}

// ============================================================================
// Complete Example - Everything together
// ============================================================================

let main = async () => {
  Console.log("=== Misskey API Demo ===\n")
  
  // 1. Connect
  let client = Misskey.connect("https://misskey.io", ~token="your-token")
  
  // 2. Post a note
  Console.log("Posting a note...")
  let noteResult = await client->Misskey.Notes.create("Testing the API!", ())
  
  switch noteResult {
  | Ok(_) => Console.log("✓ Note posted")
  | Error(msg) => Console.log(`✗ Failed: ${msg}`)
  }
  
  // 3. Get timeline
  Console.log("\nFetching timeline...")
  let timelineResult = await client->Misskey.Notes.timeline(#home, ~limit=5, ())
  
  switch timelineResult {
  | Ok(notes) => {
      Console.log("✓ Got timeline:")
      Console.log(notes)
    }
  | Error(msg) => Console.log(`✗ Failed: ${msg}`)
  }
  
  // 4. Start streaming
  Console.log("\nStarting real-time stream...")
  
  let homeCleanup = client->Misskey.Stream.timeline(#home, note => {
    Console.log("📝 Real-time note!")
  })
  
  let notifCleanup = client->Misskey.Stream.notifications(notif => {
    Console.log("🔔 Real-time notification!")
  })
  
  Console.log("✓ Stream started!\n")
  
  // Return cleanup function
  () => {
    homeCleanup.dispose()
    notifCleanup.dispose()
    Misskey.Stream.close(client)
    Console.log("👋 Cleaned up!")
  }
}

// ============================================================================
// Why this API is great:
// ============================================================================

// ✅ Minimal - Common operations are 1-2 lines
// ✅ Discoverable - Just type and autocompletion guides you
// ✅ Consistent - Everything follows the same patterns
// ✅ Simple - No builder patterns, no complex chains
// ✅ Flexible - Optional parameters for advanced use
// ✅ Type-safe - Full ReScript type checking
// ✅ Clean errors - Simple result types

// Try it yourself:
// 1. Type: myClient->Misskey.Notes.
// 2. Autocomplete shows: create, delete, timeline, react
// 3. Pick one and see the clear parameters
// 4. Done!

// Uncomment to run:
// let cleanup = await main()
// cleanup()
