// Example: Using Misskey with Cherrypick extensions
//
// This demonstrates the modular, composable API structure where:
// - Base modules contain SHARED endpoints (work on both Misskey and Cherrypick)
// - Cherrypick modules contain ONLY EXTENSIONS (new + modified endpoints)
// - You can compose both at the language level with `open`

// Import shared endpoints (work with both Misskey and Cherrypick)
// These files are in: src/generated/Account.res, src/generated/Notes.res, etc.
open Account   // 32 shared account endpoints
open Notes     // Shared notes endpoints

// Import Cherrypick extensions
// These files are in: src/generated/Cherrypick/Account.res, etc.
// They ONLY contain new and modified endpoints (not duplicates of shared)
module CherrypickAccount = Cherrypick.Account  // 67 extension endpoints
module CherrypickChat = Cherrypick.Chat        // Cherrypick-only feature
module CherrypickGroups = Cherrypick.Groups    // Cherrypick-only feature

// Create a Misskey/Cherrypick client
let client = Misskey.connect("https://kokonect.link", ~token="your-token")

// Example 1: Use shared endpoints (base only)
let useSharedEndpoints = async () => {
  Console.log("1. Using shared endpoints (work on both Misskey and Cherrypick)")
  
  // postClipsAddNote is in the base Account module (shared)
  let _result = await postClipsAddNote(
    ~body={clipid: "clip-id", noteid: "note-id"},
    ~fetch=client.fetch,
  )
  
  Console.log("   ✓ Called shared endpoint from base Account module")
}

// Example 2: Use Cherrypick-only features
let useCherrypickOnly = async () => {
  Console.log("2. Using Cherrypick-only features")
  
  // Chat feature exists ONLY in Cherrypick
  let _messages = await CherrypickChat.postChatMessagesUserTimeline(
    ~body={userId: "user-id", limit: Some(20)},
    ~fetch=client.fetch,
  )
  
  Console.log("   ✓ Called Cherrypick Chat endpoint (doesn't exist in base Misskey)")
  
  // Groups feature exists ONLY in Cherrypick  
  let _groups = await CherrypickGroups.postUsersGroupsOwned(
    ~body={},
    ~fetch=client.fetch,
  )
  
  Console.log("   ✓ Called Cherrypick Groups endpoint (doesn't exist in base Misskey)")
}

// Example 3: Compose base + extensions
// When you open both modules, you get:
// - All shared endpoints from base
// - All extension endpoints from Cherrypick (new + overrides)
let useComposedAPI = async () => {
  Console.log("3. Composing base + Cherrypick extensions")
  
  // Open both - Cherrypick extensions override/extend base
  open Account
  open CherrypickAccount
  
  // Now you have access to:
  // - 32 shared endpoints from base Account
  // - 67 extension endpoints from Cherrypick Account
  // Total: 99 endpoints with no duplication!
  
  // postClipsAddNote comes from base (shared)
  let _clip = await postClipsAddNote(
    ~body={clipid: "clip-id", noteid: "note-id"},
    ~fetch=client.fetch,
  )
  
  // postBlockingCreate is a Cherrypick extension (modified endpoint)
  let _blocking = await postBlockingCreate(
    ~body={userid: "user-id"},
    ~fetch=client.fetch,
  )
  
  Console.log("   ✓ Composed base + extensions seamlessly!")
  Console.log("   ✓ No duplication - shared endpoints defined once")
  Console.log("   ✓ Extensions override/extend as needed")
}

// Main example
let main = async () => {
  Console.log("\n🌸 Cherrypick Multi-Fork API Example\n")
  Console.log("Structure:")
  Console.log("  generated/Account.res          - 32 shared endpoints")
  Console.log("  generated/Cherrypick/Account.res - 67 extension endpoints (0 overlap!)")
  Console.log("")
  
  await useSharedEndpoints()
  Console.log("")
  
  await useCherrypickOnly()
  Console.log("")
  
  await useComposedAPI()
  Console.log("\n✅ Done!")
  Console.log("\n💡 Key benefits:")
  Console.log("   • No code duplication - shared endpoints generated once")
  Console.log("   • Extensions only contain diffs (new + modified)")
  Console.log("   • Compose at language level with 'open'")
  Console.log("   • Tree-shaking removes unused code")
}

