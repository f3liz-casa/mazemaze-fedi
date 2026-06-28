// Test file demonstrating fully qualified namespace access
// Structure:
//   - MisskeyIoGenerated.MisskeyIoGenerated.Antennas.* (generated Misskey.io API)
//   - KokonectLinkGenerated.KokonectLinkGenerated.Antennas.* (generated Kokonect.link/Cherrypick API)
//   - Cherrypick.Antennas.* (wrapper around KokonectLink generated)
//
// Users access via:
//   - Misskey.Antennas.* (existing wrapper - needs updating)
//   - Cherrypick.Antennas.* (new wrapper)

// Example 1: Using base Misskey.io endpoints
module MisskeyClient = {
  // Access via the generated module
  let createAntennaBase = MisskeyIoGenerated.MisskeyIoGenerated.Antennas.postAntennasCreate
  let listAntennas = MisskeyIoGenerated.MisskeyIoGenerated.Antennas.postAntennasList
  let deleteAntenna = MisskeyIoGenerated.MisskeyIoGenerated.Antennas.postAntennasDelete
}

// Example 2: Using Cherrypick/Kokonect.link with wrapper
module CherrypickClient = {
  // Access via Cherrypick wrapper (cleaner)
  let createAntennaCherrypick = Cherrypick.Antennas.postAntennasCreate
  let chatHistory = Cherrypick.Chat.postChatHistory
  let createGroup = Cherrypick.Groups.postUsersGroupsCreate
}

// Example 3: Direct access to generated modules
module DirectAccess = {
  // Misskey.io generated
  let misskeyNotes = MisskeyIoGenerated.MisskeyIoGenerated.Notes.postNotesCreate
  
  // Kokonect.link generated
  let kokonectNotes = KokonectLinkGenerated.KokonectLinkGenerated.Notes.postNotesCreate
  let kokonectChat = KokonectLinkGenerated.KokonectLinkGenerated.Chat.postChatMessagesCreateToUser
}

// Example 4: Type-safe fork selection
module MultiForkClient = {
  type fork = MisskeyIo | KokonectLink
  
  let postNote = (fork: fork, ~body, ~fetch) => {
    switch fork {
    | MisskeyIo => MisskeyIoGenerated.MisskeyIoGenerated.Notes.postNotesCreate(~body, ~fetch)
    | KokonectLink => KokonectLinkGenerated.KokonectLinkGenerated.Notes.postNotesCreate(~body, ~fetch)
    }
  }
}

// Example 5: Comparing modified endpoints
module EndpointComparison = {
  // Both have antennas/create but with different schemas
  let misskeyCreate = MisskeyIoGenerated.MisskeyIoGenerated.Antennas.postAntennasCreate
  let cherrypickCreate = Cherrypick.Antennas.postAntennasCreate
  
  // Cherrypick-only features (from kokonect.link)
  let chatFeature = Cherrypick.Chat.postChatMessagesCreateToUser
  let groupsFeature = Cherrypick.Groups.postUsersGroupsCreate
}
