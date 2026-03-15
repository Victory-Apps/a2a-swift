# Roadmap

## v0.1.0 (Current)

The initial release includes a complete implementation of the A2A v1.0 protocol:

- Full data model (Task, Message, Part, Artifact, AgentCard, security schemes)
- JSON-RPC 2.0 layer
- A2A Client with SSE streaming and interceptor middleware
- AgentExecutor pattern with DefaultRequestHandler orchestration
- EventQueue with AsyncSequence-based pub/sub and multi-subscriber support
- TaskStore protocol with InMemoryTaskStore reference implementation
- TaskManager for automatic event processing and store updates
- TaskUpdater convenience API for agents
- Push notification sender
- 58 tests across 8 suites
- CI/CD with GitHub Actions (macOS, Linux, iOS, tvOS, watchOS)

## Short Term

### DocC Documentation
- Add DocC catalog with getting started guide, tutorials, and architecture overview
- Host on GitHub Pages or Swift Package Index
- Add code-level documentation for all public APIs

### Sample Xcode Project
- Create a runnable Xcode project in `Examples/` with:
  - A local A2A server agent (echo or on-device LLM)
  - A SwiftUI client app that connects to it
  - Demonstrates streaming, multi-turn, and agent discovery
- Should build and run out of the box with no setup

### HTTP Framework Integration Package
- Add `A2AVapor` target for one-liner Vapor integration:
  ```swift
  app.mountA2A(handler: myHandler)
  ```
- Add `A2AHummingbird` target for Hummingbird integration
- Handle agent card serving, JSON-RPC routing, and SSE streaming automatically
- Ship as separate products in the same package (no forced dependency)

## Medium Term

### OpenTelemetry Tracing
- Optional `A2ATracing` target
- Instrument client requests and server handler methods with spans
- Propagate trace context through A2A headers
- Compatible with swift-distributed-tracing

### Persistent TaskStore Implementations
- `A2ASQLite` — lightweight local persistence using swift-sqlite or GRDB
- `A2APostgres` — production-grade store using PostgresNIO
- Ship as separate packages to avoid forcing database dependencies

### REST (HTTP+JSON) Transport
- Add support for the HTTP+JSON protocol binding alongside JSON-RPC
- RESTful routes: `POST /message:send`, `GET /tasks/{id}`, `POST /tasks/{id}:cancel`, etc.
- Share the same handler/executor layer — just a different router

### Client Enhancements
- Agent card resolver with caching and TTL
- SSE reconnection with automatic retry and last-event-id
- Connection health monitoring

### Server Enhancements
- ServerCallContext with user identity and request-scoped state
- Agent card validation (verify required fields, skill uniqueness, URL formats)
- Rate limiting middleware
- Request logging middleware

### Multi-Agent Orchestration
- Agent registry for discovering and managing multiple agents
- Routing layer that dispatches to agents based on skill matching
- Agent-to-agent communication patterns (chaining, fan-out, delegation)
