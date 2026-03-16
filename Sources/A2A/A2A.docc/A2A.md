# ``A2A``

Swift SDK for the Agent-to-Agent (A2A) protocol v1.0.

## Overview

The A2A Swift SDK provides everything you need to build and consume A2A-compatible agents in Swift. It implements the full [A2A protocol specification](https://google.github.io/A2A/) with zero dependencies — just pure Foundation.

Build agents that communicate with other agents across any language or platform. The SDK handles JSON-RPC 2.0 routing, Server-Sent Events (SSE) streaming, task lifecycle management, and push notifications so you can focus on your agent's logic.

```swift
import A2A

struct MyAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork()
        updater.addArtifact(parts: [.text("Hello from Swift!")])
        updater.complete()
    }
}

let handler = DefaultRequestHandler(executor: MyAgent(), card: myAgentCard)
let router = A2ARouter(handler: handler)
```

### Key Features

- **Full A2A v1.0 coverage** — All 11 protocol methods, 5 security schemes, streaming via SSE
- **Two-level server architecture** — High-level ``AgentExecutor`` for convenience, low-level ``A2AAgentHandler`` for full control
- **Native Swift concurrency** — async/await, actors, and AsyncSequence throughout
- **Cross-platform** — macOS, iOS, tvOS, watchOS, and Linux
- **Zero dependencies** — Pure Foundation, no third-party packages

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>

### Building Agents (Server)

- ``AgentExecutor``
- ``DefaultRequestHandler``
- ``RequestContext``
- ``TaskUpdater``

### Agent Discovery

- ``AgentCard``
- ``AgentCardResolver``
- ``AgentInterface``
- ``AgentSkill``
- ``AgentCapabilities``
- ``AgentProvider``

### Consuming Agents (Client)

- ``A2AClient``
- ``A2AClientInterceptor``
- ``BearerAuthInterceptor``
- ``APIKeyInterceptor``

### Data Model

- ``A2ATask``
- ``TaskState``
- ``TaskStatus``
- ``Message``
- ``Role``
- ``Part``
- ``Artifact``
- ``JSONValue``

### Streaming & Events

- ``StreamResponse``
- ``SendMessageResponse``
- ``TaskStatusUpdateEvent``
- ``TaskArtifactUpdateEvent``
- ``AgentEvent``
- ``EventQueue``
- ``EventQueueManager``
- ``EventSubscription``
- ``StreamResponseSequence``

### Request & Response Types

- ``SendMessageRequest``
- ``SendMessageConfiguration``
- ``GetTaskRequest``
- ``ListTasksRequest``
- ``ListTasksResponse``
- ``CancelTaskRequest``
- ``SubscribeToTaskRequest``
- ``GetExtendedAgentCardRequest``

### Task Storage

- ``TaskStore``
- ``InMemoryTaskStore``
- ``TaskManager``

### Push Notifications

- ``PushNotificationSender``
- ``TaskPushNotificationConfig``
- ``AuthenticationInfo``
- ``GetTaskPushNotificationConfigRequest``
- ``ListTaskPushNotificationConfigsRequest``
- ``ListTaskPushNotificationConfigsResponse``
- ``DeleteTaskPushNotificationConfigRequest``

### Low-Level Server

- ``A2AAgentHandler``
- ``A2ARouter``

### JSON-RPC

- ``JSONRPCRequest``
- ``JSONRPCResponse``
- ``JSONRPCError``
- ``JSONRPCId``
- ``A2AMethod``
- ``RawJSONRPCRequest``

### Errors

- ``A2AError``
- ``A2AErrorCode``

### Security

- ``SecurityScheme``
- ``SecurityRequirement``
- ``APIKeySecurityScheme``
- ``HTTPAuthSecurityScheme``
- ``OAuth2SecurityScheme``
- ``OpenIdConnectSecurityScheme``
- ``MutualTlsSecurityScheme``
- ``OAuthFlows``
- ``AuthorizationCodeOAuthFlow``
- ``ClientCredentialsOAuthFlow``
- ``DeviceCodeOAuthFlow``

### Agent Card Extensions

- ``AgentExtension``
- ``AgentCardSignature``
