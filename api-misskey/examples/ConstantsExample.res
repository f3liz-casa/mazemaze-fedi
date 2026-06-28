// Example: Using constants and utilities

open MisskeyJS
open MisskeyJS.Constants

// Display all constants
let displayConstants = () => {
  Console.log("=== Misskey Constants ===\n")

  Console.log("Notification Types:")
  notificationTypes->Array.forEach(t => Console.log(`  - ${t}`))

  Console.log("\nNote Visibilities:")
  noteVisibilities->Array.forEach(v => Console.log(`  - ${v}`))

  Console.log("\nMuted Note Reasons:")
  mutedNoteReasons->Array.forEach(r => Console.log(`  - ${r}`))

  Console.log("\nFollowing Visibilities:")
  followingVisibilities->Array.forEach(v => Console.log(`  - ${v}`))

  Console.log("\nFollowers Visibilities:")
  followersVisibilities->Array.forEach(v => Console.log(`  - ${v}`))

  Console.log(`\nTotal Permissions: ${permissions->Array.length->Int.toString}`)
  Console.log("Sample permissions:")
  permissions->Array.slice(~start=0, ~end=10)->Array.forEach(p => Console.log(`  - ${p}`))
}

// Work with typed enums
let workWithEnums = () => {
  Console.log("\n=== Working with Typed Enums ===\n")

  // Notification type conversions
  let notifType: Constants.NotificationType.t = #follow
  Console.log2("Notification type:", notifType->Constants.NotificationType.toString)

  let parsed = Constants.NotificationType.fromString("mention")
  switch parsed {
  | Some(nt) => Console.log2("Parsed notification type:", nt)
  | None => Console.log("Failed to parse notification type")
  }

  // Visibility conversions
  let visibility: Constants.Visibility.t = #public
  Console.log2("\nVisibility:", visibility->Constants.Visibility.toString)

  let parsedVis = Constants.Visibility.fromString("followers")
  switch parsedVis {
  | Some(v) => Console.log2("Parsed visibility:", v)
  | None => Console.log("Failed to parse visibility")
  }

  // Follow visibility
  let followVis: Constants.FollowVisibility.t = #followers
  Console.log2("\nFollow visibility:", followVis->Constants.FollowVisibility.toString)

  // Muted note reason
  let mutedReason: Constants.MutedNoteReason.t = #spam
  Console.log2("Muted reason:", mutedReason->Constants.MutedNoteReason.toString)
}

// Nyaize text (cat mode) - REMOVED
// Note: nyaize function was client-side specific functionality from misskey-js
// It has been removed in the native ReScript implementation as it's typically
// handled client-side by the Misskey frontend
let testNyaize = () => {
  Console.log("\n=== Nyaize Text (Removed) ===\n")
  Console.log("The nyaize function has been removed as it was client-side specific.")
  Console.log("This functionality is typically handled by the Misskey web frontend.")
}

// Check permissions
let checkPermissions = () => {
  Console.log("\n=== Checking Permissions ===\n")

  let requiredPerms = ["read:account", "write:notes", "read:notifications"]

  Console.log("Required permissions for this app:")
  requiredPerms->Array.forEach(perm => {
    let hasPermission = permissions->Array.includes(perm)
    let status = hasPermission ? "✓" : "✗"
    Console.log(`  ${status} ${perm}`)
  })

  // List all admin permissions
  let adminPerms =
    permissions->Array.filter(p =>
      p->String.startsWith("read:admin:") || p->String.startsWith("write:admin:")
    )
  Console.log(`\nAdmin permissions (${adminPerms->Array.length->Int.toString} total):`)
  adminPerms->Array.slice(~start=0, ~end=5)->Array.forEach(p => Console.log(`  - ${p}`))
  Console.log("  ...")
}

// Main function
let main = () => {
  displayConstants()
  workWithEnums()
  testNyaize()
  checkPermissions()
}

// Run example
// Uncomment to run:
// main()
