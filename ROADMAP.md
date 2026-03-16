# Roadmap

## Completed

### v0.1.0 — Core SDK
- Full A2A v1.0 data model (Task, Message, Part, Artifact, AgentCard, security schemes)
- JSON-RPC 2.0 layer
- A2A Client with SSE streaming and interceptor middleware
- AgentExecutor pattern with DefaultRequestHandler orchestration
- EventQueue with AsyncSequence-based pub/sub and multi-subscriber support
- TaskStore protocol with InMemoryTaskStore reference implementation
- TaskManager for automatic event processing and store updates
- TaskUpdater convenience API for agents
- Push notification sender
- CI/CD with GitHub Actions (macOS, Linux, iOS, tvOS, watchOS)

### v0.1.1 — Samples, Examples & Bugfix
- **A2AServer** sample — Dockerized Vapor server with echo, LLM (Ollama), and product catalog agents, streaming responses, and conversation memory
- **A2AChatClient** sample — macOS SwiftUI chat client with multi-agent connectivity, Apple Intelligence orchestration, and streaming UI
- Single-file code examples: EchoAgent, A2AClientApp, OnDeviceLLMAgent
- EventQueueManager bugfix for closed queue reuse
- 60 tests across 8 suites

### v0.2.0 — Spec Compliance
- Add UNSPECIFIED zero-value variants to TaskState and Role enums (proto3 requirement)
- Fix SecurityRequirement encoding to use proto-compliant format with StringList wrapper
- Add missing pagination fields to push notification list request/response
- Add StringList type matching proto StringList message

### DocC Documentation
- DocC catalog with getting started guide and architecture overview
- Reference sample apps for hands-on walkthroughs
- Hosted on Swift Package Index (auto-generated from DocC catalog)

### v0.3.0 — Vapor Integration & Client Caching
- `A2AVapor` target — one-liner Vapor integration: `app.mountA2A(handler:)`
- Agent card serving, JSON-RPC routing, and SSE streaming handled automatically
- Separate product in the same package (no forced Vapor dependency)
- `AgentCardResolver` actor with TTL-based caching for multi-agent discovery
- Updated A2AServer sample to use `A2AVapor`

## Short Term

### A2AHummingbird Integration
- Add `A2AHummingbird` target for Hummingbird 2.0+ integration
- Same pattern as A2AVapor — separate product, no forced dependency

### Client Enhancements
- SSE reconnection with automatic retry and last-event-id
- Connection health monitoring

## Medium Term

### Server Enhancements
- ServerCallContext with user identity and request-scoped state
- Agent card validation (verify required fields, skill uniqueness, URL formats)

### Multi-Agent Orchestration
- Promote patterns from A2AChatClient's OrchestratorService into the SDK
- Agent registry for discovering and managing multiple agents
- Routing layer that dispatches to agents based on skill matching
- Agent-to-agent communication patterns (chaining, fan-out, delegation)
- Error propagation and timeout/cancellation semantics for fan-out

### REST (HTTP+JSON) Transport
- Add support for the HTTP+JSON protocol binding alongside JSON-RPC (pending A2A spec)
- RESTful routes: `POST /message:send`, `GET /tasks/{id}`, `POST /tasks/{id}:cancel`, etc.
- Share the same handler/executor layer — just a different router

### Testing Utilities
- `A2ATesting` target with mock client and server
- Fixture builders for AgentCard, Task, Message, and other protocol types
- Test helpers for asserting streaming event sequences

### Persistent TaskStore Implementations
- `A2ASQLite` — lightweight local persistence using GRDB
- `A2APostgres` — production-grade store using PostgresNIO
- Ship as separate packages to avoid forcing database dependencies

### OpenTelemetry Tracing
- Optional `A2ATracing` target
- Instrument client requests and server handler methods with spans
- Propagate trace context through A2A headers
- Compatible with swift-distributed-tracing

## Distribution & Marketing

### Package Registries
- [ ] Submit to [Swift Package Index](https://swiftpackageindex.com/add-a-package) — primary discovery channel, linked from swift.org
- [ ] Submit to [SwiftPackageRegistry.com](https://swiftpackageregistry.com)

### A2A Ecosystem Listings
- [ ] PR to [`a2aproject/A2A` — `docs/community.md`](https://github.com/a2aproject/A2A) — request listing as community Swift SDK (currently only Python, Go, JS, Java, .NET)
- [ ] PR to [`ai-boost/awesome-a2a`](https://github.com/ai-boost/awesome-a2a) — most prominent A2A ecosystem list
- [ ] PR to [`nMaroulis/awesome-a2a-libraries`](https://github.com/nMaroulis/awesome-a2a-libraries) — SDK-by-language list, no Swift entry yet

### Swift Community
- [ ] Nominate for [swift.org Community Showcase](https://www.swift.org/packages/showcase.html) via [Swift Forums nomination thread](https://forums.swift.org/t/nominations-for-the-packages-community-showcase-on-swift-org/68168)
- [ ] PR to [`matteocrippa/awesome-swift`](https://github.com/matteocrippa/awesome-swift) (Network section)
- [ ] PR to [`vsouza/awesome-ios`](https://github.com/vsouza/awesome-ios) (Networking category)
- [ ] Announcement post on [Swift Forums](https://forums.swift.org/)

### Newsletters & Media
- [ ] Submit tip to [iOS Dev Weekly](https://iosdevweekly.com/) (~46K readers)
- [ ] Submit tip to [SwiftLee Weekly](https://www.avanderlee.com/swiftlee-weekly-subscribe/) (~27K readers)
- [ ] Submit to [iOS Cookies](https://ioscookies.com/) (open-source Swift library newsletter)

## Long Term

### Protocol Versioning
- Strategy for supporting A2A spec updates (v1.1+, breaking changes)
- Version negotiation between client and server
- Deprecation and migration path for older protocol versions
