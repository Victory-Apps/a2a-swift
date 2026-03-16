# Getting Started

Build your first A2A agent in Swift.

## Overview

This guide walks you through creating an A2A agent and a client that talks to it. By the end, you'll understand the core SDK patterns and be ready to build production agents.

## Add the Dependency

Add A2A to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Victory-Apps/a2a-swift.git", from: "0.3.0")
]
```

Then add it to your target:

```swift
.target(name: "MyAgent", dependencies: [
    .product(name: "A2A", package: "a2a-swift")
])
```

For Vapor integration, use `A2AVapor` instead — it re-exports `A2A` so you only need one import:

```swift
.target(name: "MyAgent", dependencies: [
    .product(name: "A2AVapor", package: "a2a-swift")
])
```

## Build an Agent

The fastest way to build an agent is with ``AgentExecutor`` and ``DefaultRequestHandler``. You implement the business logic; the SDK handles everything else.

### Step 1: Implement AgentExecutor

``AgentExecutor`` is the protocol for your agent's logic. It receives a ``RequestContext`` with the user's message and a ``TaskUpdater`` for emitting results.

```swift
import A2A

struct EchoAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork(message: "Processing...")
        updater.addArtifact(
            name: "echo-response",
            parts: context.userMessage.parts
        )
        updater.complete(message: "Done!")
    }
}
```

The ``TaskUpdater`` provides methods to control the task lifecycle:
- ``TaskUpdater/startWork(message:)`` — Signal work has begun
- ``TaskUpdater/addArtifact(artifactId:name:description:parts:append:lastChunk:)`` — Emit output
- ``TaskUpdater/streamText(_:artifactId:name:append:lastChunk:)`` — Stream text incrementally
- ``TaskUpdater/complete(message:)`` — Mark the task as done
- ``TaskUpdater/fail(message:)`` — Mark the task as failed
- ``TaskUpdater/requireInput(message:)`` — Ask the user for more input

### Step 2: Define Your Agent Card

The ``AgentCard`` describes your agent's identity and capabilities. Clients discover this at `/.well-known/agent-card.json`.

```swift
let card = AgentCard(
    name: "Echo Agent",
    description: "Echoes back whatever you send.",
    supportedInterfaces: [
        AgentInterface(url: "http://localhost:8080")
    ],
    version: "1.0.0",
    capabilities: AgentCapabilities(streaming: true),
    skills: [
        AgentSkill(
            id: "echo",
            name: "Echo",
            description: "Echoes input back",
            tags: ["echo", "test"]
        )
    ]
)
```

### Step 3: Wire Up the Handler and Router

``DefaultRequestHandler`` connects your executor to the full A2A protocol — task creation, event processing, store updates, SSE streaming, and push notifications are all automatic.

``A2ARouter`` dispatches incoming JSON-RPC requests to the handler.

```swift
let handler = DefaultRequestHandler(
    executor: EchoAgent(),
    card: card
)
let router = A2ARouter(handler: handler)
```

### Step 4: Integrate with an HTTP Framework

With `A2AVapor`, integration is a single line:

```swift
import A2AVapor
import Vapor

let app = try await Application.make()
app.mountA2A(handler: handler)
try await app.execute()
```

This automatically registers:
- `GET /.well-known/agent-card.json` — Agent card discovery
- `POST /` — JSON-RPC endpoint with SSE streaming support

You can also mount at a custom path:

```swift
app.mountA2A(handler: handler, path: "a2a")
```

> Note: If you're using a different HTTP framework, the ``A2ARouter`` is framework-agnostic — its ``A2ARouter/route(body:)`` method returns a ``A2ARouter/RouteResult`` that you can map to any framework's response types.

## Build a Client

``A2AClient`` communicates with any A2A-compatible agent — Swift, Python, JavaScript, Java, Go, or .NET.

### Discover and Send Messages

```swift
let client = A2AClient(baseURL: URL(string: "http://localhost:8080")!)

// Discover the agent
let card = try await client.fetchAgentCard()
print("Connected to: \(card.name)")

// Send a message
let response = try await client.sendMessage(SendMessageRequest(
    message: Message(role: .user, parts: [.text("Hello!")])
))
```

### Stream Responses

For real-time streaming, use ``A2AClient/sendStreamingMessage(_:)``:

```swift
let stream = try await client.sendStreamingMessage(SendMessageRequest(
    message: Message(role: .user, parts: [.text("Tell me a story")])
))

for try await event in stream {
    switch event {
    case .task(let task):
        print("Task created: \(task.id)")
    case .statusUpdate(let update):
        print("Status: \(update.status.state)")
    case .artifactUpdate(let update):
        let text = update.artifact.parts.compactMap(\.text).joined()
        print(text, terminator: "")
    case .message(let msg):
        print(msg.parts.compactMap(\.text).joined())
    }
}
```

### Add Authentication

Use interceptors to add auth headers to every request:

```swift
let client = A2AClient(
    baseURL: url,
    interceptors: [BearerAuthInterceptor(token: "my-token")]
)
```

Or create a custom interceptor:

```swift
struct LoggingInterceptor: A2AClientInterceptor {
    func before(request: inout URLRequest, method: A2AMethod) async throws {
        print("-> \(method.rawValue)")
    }

    func after(response: URLResponse, data: Data, method: A2AMethod) async throws -> Data {
        print("<- \(data.count) bytes")
        return data
    }
}
```

## Streaming Agents

Agents that stream output word-by-word use ``TaskUpdater/streamText(_:artifactId:name:append:lastChunk:)``:

```swift
struct StreamingAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork()
        let artifactId = UUID().uuidString

        for word in context.userText.split(separator: " ") {
            try await Task.sleep(for: .milliseconds(100))
            updater.streamText("\(word) ", artifactId: artifactId)
        }

        updater.streamText("", artifactId: artifactId, lastChunk: true)
        updater.complete()
    }
}
```

## Multi-Turn Conversations

Agents can request additional input from the user using ``TaskUpdater/requireInput(message:)``:

```swift
struct ConversationalAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        if context.isNewTask {
            updater.startWork()
            updater.sendMessage(parts: [.text("What's your name?")])
            updater.requireInput(message: "Please provide your name")
        } else {
            updater.startWork()
            updater.addArtifact(parts: [.text("Hello, \(context.userText)!")])
            updater.complete()
        }
    }
}
```

The client continues the conversation by referencing the task ID:

```swift
// First message creates a task
let response = try await client.sendMessage(request)
let taskId = /* extract from response */

// Follow-up references the existing task
var followUp = SendMessageRequest(
    message: Message(role: .user, parts: [.text("Alice")])
)
followUp.message.taskId = taskId
let response2 = try await client.sendMessage(followUp)
```

## Next Steps

- Read <doc:Architecture> to understand how the SDK components fit together
- Explore the sample apps in the `Samples/` directory
- Check the ``AgentExecutor`` and ``A2AClient`` API references for all available methods
