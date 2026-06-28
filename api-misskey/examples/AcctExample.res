// Example: Using Acct utilities

open MisskeyJS

// Parse account strings
let parseAccounts = () => {
  Console.log("=== Parsing Accounts ===\n")

  // Local user (no host)
  let local1 = Acct.parse("user")
  Console.log2("Parsed 'user':", local1)
  Console.log2("  Is local:", local1->Acct.isLocal)
  Console.log2("  Display name:", local1->Acct.getDisplayName)

  // Local user with @
  let local2 = Acct.parse("@user")
  Console.log2("\nParsed '@user':", local2)

  // Remote user
  let remote1 = Acct.parse("user@example.com")
  Console.log2("\nParsed 'user@example.com':", remote1)
  Console.log2("  Is remote:", remote1->Acct.isRemote)
  Console.log2("  Display name:", remote1->Acct.getDisplayName)

  // Remote user with @
  let remote2 = Acct.parse("@user@example.com")
  Console.log2("\nParsed '@user@example.com':", remote2)
}

// Create and convert accounts
let createAccounts = () => {
  Console.log("\n=== Creating Accounts ===\n")

  // Create local account
  let localAcct = Acct.make(~username="alice", ())
  Console.log2("Created local account:", localAcct)
  Console.log2("  As string:", localAcct->Acct.toString)

  // Create remote account
  let remoteAcct = Acct.make(~username="bob", ~host="misskey.example", ())
  Console.log2("\nCreated remote account:", remoteAcct)
  Console.log2("  As string:", remoteAcct->Acct.toString)
}

// Work with user data
let workWithUsers = () => {
  Console.log("\n=== Working with User Data ===\n")

  // Simulate user data
  let _user1 = {
    "username": "alice",
    "host": JSON.Encode.null,
  }

  let _user2 = {
    "username": "bob",
    "host": "misskey.example",
  }

  // Parse and display
  let acct1 = Acct.make(~username="alice", ())
  Console.log2("User 1:", acct1->Acct.getDisplayName)

  let acct2 = Acct.make(~username="bob", ~host="misskey.example", ())
  Console.log2("User 2:", acct2->Acct.getDisplayName)
}

// Main function
let main = () => {
  parseAccounts()
  createAccounts()
  workWithUsers()
}

// Run example
// Uncomment to run:
// main()
