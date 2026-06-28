// Example: Simple WebSocket Test - Test the native WebSocket implementation
// This is a minimal example to verify the WebSocket connection works correctly
//
// ⚠️ NOTE: This example uses the DEPRECATED MisskeyJS API.
// For new code, use: Misskey.connect() and Misskey.Stream.timeline()
// See examples/QuickStart.res for the new API.

open MisskeyJS

// Simple test to verify WebSocket connection and timeline streaming
let testWebSocketConnection = (~origin: string, ~credential: option<string>=?, ()) => {
  Console.log("=== Testing Native WebSocket Implementation ===\n")
  
  // Create client
  Console.log(`Connecting to ${origin}...`)
  let client = Client.make(~origin, ~credential?, ())
  
  // Track connection state
  let isConnected = ref(false)
  
  // Setup connection handlers
  client->Client.onConnected(() => {
    Console.log("✓ WebSocket connected successfully!")
    isConnected := true
  })
  
  client->Client.onDisconnected(() => {
    Console.log("✗ WebSocket disconnected")
    isConnected := false
  })
  
  // Subscribe to home timeline to test channel messages
  Console.log("Subscribing to home timeline...")
  let timelineSub = client
    ->Timeline.subscribe(~type_=#home, ())
    ->Timeline.onNote(note => {
      // Log the raw JSON to verify we're receiving messages
      Console.log("📝 Received note:")
      Console.log(note)
    })
  
  // Return cleanup function
  let cleanup = () => {
    Console.log("\n=== Cleanup ===")
    timelineSub->Timeline.dispose
    client->Client.close
    Console.log("✓ Test complete")
  }
  
  cleanup
}

// Quick test with public instance (no authentication)
let testPublic = () => {
  testWebSocketConnection(~origin="https://misskey.io", ())
}

// Test with authentication
let testAuthenticated = (~origin: string, ~token: string) => {
  testWebSocketConnection(~origin, ~credential=token, ())
}

// For manual testing in browser console:
// 1. Build the project: npm run build
// 2. Import in your app
// 3. Call testPublic() to test public connection
// 4. Call testAuthenticated(~origin="https://your-instance.com", ~token="your-token") for authenticated test

// Example usage (commented out):
// let cleanup = testPublic()
// 
// // After testing, cleanup:
// cleanup()
//
// Or with authentication:
// let cleanup = testAuthenticated(
//   ~origin="https://misskey.example.com",
//   ~token="your-api-token-here"
// )
// cleanup()
