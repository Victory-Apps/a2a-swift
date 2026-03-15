// A2A Swift SDK
// An implementation of the Google A2A (Agent-to-Agent) protocol v1.0 for Swift.
//
// This package provides:
// - Complete A2A data model types (Task, Message, Part, Artifact, AgentCard, etc.)
// - JSON-RPC 2.0 request/response layer
// - A2AClient for communicating with A2A agents (including SSE streaming)
// - A2AAgentHandler protocol and A2ARouter for building A2A agents
// - InMemoryTaskStore for development and testing
//
// Usage:
//   import A2A
//
// Client example:
//   let client = A2AClient(baseURL: URL(string: "https://agent.example.com")!)
//   let card = try await client.fetchAgentCard()
//   let response = try await client.sendMessage(SendMessageRequest(
//       message: Message(role: .user, parts: [.text("Hello")])
//   ))
//
// Server example:
//   struct MyAgent: A2AAgentHandler {
//       func agentCard() async throws -> AgentCard { ... }
//       func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse { ... }
//       func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask { ... }
//       func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask { ... }
//   }
//   let router = A2ARouter(handler: MyAgent())
