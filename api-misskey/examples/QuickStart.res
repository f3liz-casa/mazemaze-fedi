// QuickStart.res - Get started with Misskey in 60 seconds!

// ============================================================================
// Step 1: Connect (5 seconds)
// ============================================================================

// Public instance (no authentication)
let client = Misskey.connect("https://misskey.io")

// With authentication
let myClient = Misskey.connect("https://misskey.io", ~token="your-token")

// ============================================================================
// Step 2: Try the API (30 seconds)
// ============================================================================

// Post a note
let postNote = async () => {
  await myClient->Misskey.Notes.create("Hello, Misskey!", ())
}

// Get your timeline
let getTimeline = async () => {
  await myClient->Misskey.Notes.timeline(#home, ())
}

// React to a note
let reactToNote = async () => {
  await myClient->Misskey.Notes.react("note-id", "👍")
}

// ============================================================================
// Step 3: Real-time streaming (25 seconds)
// ============================================================================

// Stream home timeline
let streamHome = myClient->Misskey.Stream.timeline(#home, note => {
  Console.log2("New note!", note)
})

// Stream notifications
let streamNotifications = myClient->Misskey.Stream.notifications(notif => {
  Console.log2("New notification!", notif)
})

// ============================================================================
// Done! That's it!
// ============================================================================

// Cleanup when done:
// streamHome.dispose()
// streamNotifications.dispose()
// myClient->Misskey.close

// ============================================================================
// Discover more with autocompletion:
// ============================================================================

// Just type: myClient->Misskey.Notes.
// Autocomplete shows all available methods!
//
// - create(text, ~visibility?, ())
// - delete(noteId)
// - timeline(#home | #local | #global, ())
// - react(noteId, reaction)
//
// Type: myClient->Misskey.Stream.
// Autocomplete shows:
// - timeline(#home | #local | #global, onNote)
// - notifications(onNotification)
// - onConnected(callback)
// - onDisconnected(callback)
// - close()
//
// Everything you need is right at your fingertips!
