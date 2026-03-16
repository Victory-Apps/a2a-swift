# Architecture

Understand how the SDK components work together.

## Overview

The A2A Swift SDK has a layered architecture with two levels of abstraction for building servers, a client layer for consuming agents, and a shared data model.

```
┌─────────────────────────────────────────────────┐
│                  Your Agent                      │
│              (AgentExecutor)                      │
├─────────────────────────────────────────────────┤
│           DefaultRequestHandler                  │
│   ┌──────────┐  ┌───────────┐  ┌─────────────┐ │
│   │TaskManager│  │EventQueue │  │TaskUpdater   │ │
│   │           │  │Manager    │  │              │ │
│   └──────────┘  └───────────┘  └─────────────┘ │
│        │                                         │
│   ┌──────────┐                                   │
│   │TaskStore │  (InMemoryTaskStore or custom)    │
│   └──────────┘                                   │
├─────────────────────────────────────────────────┤
│              A2ARouter                           │
│         (JSON-RPC dispatch)                      │
├─────────────────────────────────────────────────┤
│           HTTP Framework                         │
│      (Vapor, Hummingbird, etc.)                  │
└─────────────────────────────────────────────────┘
```

## Two-Level Server Architecture

### High Level: AgentExecutor (Recommended)

For most agents, implement ``AgentExecutor`` and let ``DefaultRequestHandler`` manage everything else:

```swift
struct MyAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork()
        // Your logic here
        updater.complete()
    }
}

let handler = DefaultRequestHandler(executor: MyAgent(), card: card)
```

``DefaultRequestHandler`` automatically:
- Creates and manages tasks via ``TaskManager``
- Processes events from ``EventQueue`` and persists them to ``TaskStore``
- Handles SSE streaming for `SendStreamingMessage` and `SubscribeToTask`
- Delivers push notifications via ``PushNotificationSender``
- Closes event queues when agents finish or fail

### Low Level: A2AAgentHandler

For full control over request handling, implement ``A2AAgentHandler`` directly. This gives you access to every protocol method but requires you to manage task lifecycle yourself.

```swift
struct CustomHandler: A2AAgentHandler {
    func agentCard() async throws -> AgentCard { card }

    func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        // Full control over task creation, execution, and response
    }

    // ... other protocol methods
}
```

Default implementations are provided for optional methods (streaming, push notifications, extended agent card), so you only need to implement what your agent supports.

## Event-Driven Processing

The SDK uses an event-driven architecture for streaming and task state management.

### Event Flow

1. Your ``AgentExecutor`` calls methods on ``TaskUpdater`` (e.g., `startWork()`, `addArtifact()`, `complete()`)
2. ``TaskUpdater`` enqueues ``AgentEvent`` values into an ``EventQueue``
3. ``TaskManager`` subscribes to the queue and applies each event to the ``TaskStore``
4. For streaming requests, ``A2ARouter`` subscribes to the same queue and delivers events as SSE
5. If push notifications are configured, ``PushNotificationSender`` delivers events to webhooks

```
AgentExecutor → TaskUpdater → EventQueue ──┬── TaskManager → TaskStore
                                           ├── SSE Subscriber (streaming)
                                           └── PushNotificationSender
```

### Multi-Subscriber Support

``EventQueue`` supports multiple independent subscribers via ``EventQueue/subscribe()``. Each subscriber receives all events from the point of subscription, enabling:

- The ``TaskManager`` to persist state
- One or more SSE connections to stream events to clients
- Push notification delivery

Subscriptions are independent — one slow subscriber won't block others.

## Task Lifecycle

Tasks follow a state machine defined by ``TaskState``:

```
                    ┌─────────────┐
                    │  submitted  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
               ┌────│   working   │────┐
               │    └──────┬──────┘    │
               │           │           │
        ┌──────▼──────┐    │    ┌──────▼──────┐
        │inputRequired│    │    │ authRequired │
        └──────┬──────┘    │    └──────┬──────┘
               │           │           │
               └───────────┼───────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
   │  completed  │ │    failed   │ │  canceled   │
   └─────────────┘ └─────────────┘ └─────────────┘
```

Terminal states (``TaskState/isTerminal``) — `completed`, `failed`, `canceled`, `rejected` — cannot transition further. Interrupted states (``TaskState/isInterrupted``) — `inputRequired`, `authRequired` — wait for the client to send a follow-up message.

## Task Storage

The ``TaskStore`` protocol defines persistence for tasks and push notification configs. The SDK ships with ``InMemoryTaskStore`` for development and testing.

For production, implement ``TaskStore`` with your preferred backend:

```swift
actor PostgresTaskStore: TaskStore {
    func createTask(contextId: String?, status: TaskStatus, metadata: [String: JSONValue]?) async throws -> A2ATask {
        // INSERT INTO tasks ...
    }
    // ... other methods
}

let handler = DefaultRequestHandler(
    executor: MyAgent(),
    card: card,
    store: PostgresTaskStore(pool: dbPool)
)
```

## Client Architecture

``A2AClient`` communicates with any A2A agent over HTTP:

```
A2AClient ── URLRequest ── JSON-RPC/SSE ── Agent
     │
     ├── A2AClientInterceptor (before/after hooks)
     ├── Auto-incrementing request IDs
     └── Platform-aware SSE parsing (Foundation vs FoundationNetworking)
```

Interceptors (``A2AClientInterceptor``) form a pipeline that can modify requests and responses. The SDK includes ``BearerAuthInterceptor`` and ``APIKeyInterceptor`` for common auth patterns.

On Apple platforms, streaming uses `URLSession.bytes` for true incremental SSE. On Linux (`FoundationNetworking`), it falls back to buffered parsing.

## JSON-RPC Layer

The SDK includes a complete JSON-RPC 2.0 implementation:

- ``JSONRPCRequest`` / ``JSONRPCResponse`` — Typed request and response envelopes
- ``RawJSONRPCRequest`` — For initial parsing before method dispatch
- ``A2AMethod`` — All 11 A2A protocol methods
- ``JSONRPCError`` — Error objects with A2A error code mapping

``A2ARouter`` uses this layer to parse incoming requests, dispatch to the handler, and format responses — including wrapping streaming responses in SSE-formatted JSON-RPC envelopes.
