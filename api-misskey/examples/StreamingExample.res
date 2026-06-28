// Example: Streaming with rescript-misskey (Unified API)
//
// ⚠️ NOTE: This example uses the DEPRECATED MisskeyJS API.
// For new code, use the simpler Misskey API instead!
//
// See examples/NewAPIExample.res or examples/QuickStart.res for the new API.
// This example is kept for reference and backward compatibility.

open MisskeyJS

// Create a unified client (handles both API and streaming)
let client = Client.make(~origin="https://misskey.example", ~credential="your-token", ())

// Connection status handlers
let setupConnectionHandlers = () => {
  client->Client.onConnected(() => {
    Console.log("✓ Connected to Misskey stream")
  })

  client->Client.onDisconnected(() => {
    Console.log("✗ Disconnected from Misskey stream")
  })
}

// Listen to notifications via unified Notifications module
let listenToNotifications = () => {
  Console.log("Listening to notifications...")

  // Subscribe returns a subscription that can be piped to attach handlers
  let sub =
    client
    ->Notifications.subscribe
    ->Notifications.onNotification(notif => {
      Console.log2("🔔 New notification:", notif)
    })
    ->Notifications.onMention(note => {
      Console.log2("💬 You were mentioned:", note)
    })
    ->Notifications.onReply(note => {
      Console.log2("↩️ New reply:", note)
    })
    ->Notifications.onRenote(note => {
      Console.log2("🔁 Your note was renoted:", note)
    })
    ->Notifications.onFollow(user => {
      Console.log2("👤 New follower:", user)
    })
    ->Notifications.onFollowed(user => {
      Console.log2("✓ You followed:", user)
    })
    ->Notifications.onMeUpdated(user => {
      Console.log2("📝 Your profile was updated:", user)
    })
    ->Notifications.onReadAllNotifications(() => {
      Console.log("✓ All notifications marked as read")
    })

  sub
}

// Listen to home timeline via unified Timeline module
let listenToHomeTimeline = () => {
  Console.log("Listening to home timeline...")

  let sub =
    client
    ->Timeline.subscribe(
      ~type_=#home,
      ~params={
        withRenotes: true,
        withFiles: false,
      },
      (),
    )
    ->Timeline.onNote(note => {
      Console.log2("🏠 New note in home timeline:", note)
    })

  sub
}

// Listen to local timeline
let listenToLocalTimeline = () => {
  Console.log("Listening to local timeline...")

  let sub =
    client
    ->Timeline.subscribe(
      ~type_=#local,
      ~params={
        withRenotes: true,
        withReplies: true,
        withFiles: false,
      },
      (),
    )
    ->Timeline.onNote(note => {
      Console.log2("📍 New note in local timeline:", note)
    })

  sub
}

// Listen to global timeline
let listenToGlobalTimeline = () => {
  Console.log("Listening to global timeline...")

  let sub =
    client
    ->Timeline.subscribe(
      ~type_=#global,
      ~params={
        withRenotes: true,
        withFiles: false,
      },
      (),
    )
    ->Timeline.onNote(note => {
      Console.log2("🌐 New note in global timeline:", note)
    })

  sub
}

// Listen to drive events (less-common, via Stream submodule)
let listenToDrive = () => {
  Console.log("Listening to drive events...")

  let sub =
    client
    ->Stream.Drive.use
    ->Stream.Drive.onFileCreated(file => {
      Console.log2("📁 File created:", file)
    })
    ->Stream.Drive.onFileDeleted(fileId => {
      Console.log2("🗑️ File deleted:", fileId)
    })
    ->Stream.Drive.onFileUpdated(file => {
      Console.log2("📝 File updated:", file)
    })
    ->Stream.Drive.onFolderCreated(folder => {
      Console.log2("📂 Folder created:", folder)
    })
    ->Stream.Drive.onFolderDeleted(folderId => {
      Console.log2("🗑️ Folder deleted:", folderId)
    })

  sub
}

// Listen to server stats (admin only, via Stream submodule)
let listenToServerStats = () => {
  Console.log("Listening to server stats...")

  let sub =
    client
    ->Stream.ServerStats.use
    ->Stream.ServerStats.onStats(statsData => {
      Console.log2("📊 Server stats:", statsData)
    })
    ->Stream.ServerStats.onStatsLog(statsLog => {
      Console.log2("📈 Server stats log:", statsLog)
    })

  // Request historical stats
  let _ = sub->Stream.ServerStats.requestLog(~id="stats-1", ~length=50)

  sub
}

// Main function
let main = () => {
  Console.log("=== Misskey Streaming Examples (Unified API) ===\n")

  setupConnectionHandlers()

  // Start listening to various channels
  let notificationSub = listenToNotifications()
  let homeSub = listenToHomeTimeline()
  let localSub = listenToLocalTimeline()

  // Cleanup function
  let cleanup = () => {
    Console.log("\nCleaning up connections...")
    notificationSub->Notifications.dispose
    homeSub->Timeline.dispose
    localSub->Timeline.dispose
    client->Client.close
    Console.log("✓ All connections closed")
  }

  // Return cleanup function
  cleanup
}

// Run example
// Uncomment to run:
// let cleanup = main()
// // Later, to cleanup:
// // cleanup()
