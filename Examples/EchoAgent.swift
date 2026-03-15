// Example: Echo Agent using the A2A SDK
//
// This demonstrates the AgentExecutor pattern where you only implement
// business logic and the SDK handles everything else.
//
// To use this in a real app, integrate the A2ARouter with your HTTP framework
// (e.g., Vapor, Hummingbird, or SwiftNIO directly).

import A2A
import Foundation

// MARK: - 1. Implement AgentExecutor (your business logic)

struct EchoAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        // Signal that we're working
        updater.startWork(message: "Processing your request...")

        // Echo back the user's input as an artifact
        updater.addArtifact(
            name: "echo-response",
            description: "Echoed user input",
            parts: context.userMessage.parts
        )

        // Mark as complete
        updater.complete(message: "Echoed your message back!")
    }
}

// MARK: - 2. Define the agent card

let echoAgentCard = AgentCard(
    name: "Echo Agent",
    description: "A simple agent that echoes back whatever you send it.",
    supportedInterfaces: [
        AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
    ],
    provider: AgentProvider(url: "https://example.com", organization: "Example Inc."),
    version: "1.0.0",
    capabilities: AgentCapabilities(streaming: true, pushNotifications: false),
    defaultInputModes: ["text/plain"],
    defaultOutputModes: ["text/plain"],
    skills: [
        AgentSkill(
            id: "echo",
            name: "Echo",
            description: "Echoes back whatever you send",
            tags: ["echo", "test"],
            examples: ["Hello!", "What is 2+2?"]
        )
    ]
)

// MARK: - 3. Wire it up

// The DefaultRequestHandler orchestrates everything:
// - Creates tasks
// - Runs your AgentExecutor
// - Processes events and updates the task store
// - Handles SSE streaming
// - Manages push notifications
let handler = DefaultRequestHandler(
    executor: EchoAgent(),
    card: echoAgentCard
)

// The router handles JSON-RPC dispatch
let router = A2ARouter(handler: handler)

// MARK: - 4. Integrate with your HTTP framework

// With Vapor:
//
//   app.get(".well-known", "agent-card.json") { req async throws -> Response in
//       let data = try await router.handleAgentCardRequest()
//       return Response(status: .ok, body: .init(data: data))
//   }
//
//   app.post { req async throws -> Response in
//       let body = req.body.data ?? Data()
//       let result = try await router.route(body: body)
//       switch result {
//       case .response(let data):
//           return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
//       case .stream(let stream):
//           return Response(status: .ok, headers: ["Content-Type": "text/event-stream"]) { writer in
//               for try await chunk in stream { try await writer.write(chunk) }
//           }
//       case .agentCard(let data):
//           return Response(status: .ok, body: .init(data: data))
//       }
//   }

// MARK: - 5. Streaming Agent Example

struct StreamingTranslationAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork(message: "Translating...")

        let artifactId = UUID().uuidString

        // Simulate streaming translation word by word
        let words = context.userText.split(separator: " ")
        for (index, word) in words.enumerated() {
            // Simulate processing delay
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            updater.streamText(
                "[\(word)] ",
                artifactId: artifactId,
                name: "translation",
                append: index > 0,
                lastChunk: index == words.count - 1
            )
        }

        updater.complete(message: "Translation complete!")
    }
}

// MARK: - 6. Multi-turn Agent Example

struct ConversationalAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        let text = context.userText.lowercased()

        if text.contains("hello") || text.contains("hi") {
            updater.startWork()
            updater.addArtifact(parts: [.text("Hello! What can I help you with?")])
            // Don't complete -- ask for more input
            updater.requireInput(message: "What would you like to know?")
        } else if text.contains("bye") {
            updater.startWork()
            updater.addArtifact(parts: [.text("Goodbye!")])
            updater.complete()
        } else {
            updater.startWork()
            updater.addArtifact(parts: [.text("You said: \(context.userText)")])
            updater.requireInput(message: "Anything else?")
        }
    }
}
