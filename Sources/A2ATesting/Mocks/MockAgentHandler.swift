import Foundation

/// A pre-wired ``A2AAgentHandler`` for testing server-side components.
///
/// Wraps ``DefaultRequestHandler`` with a configurable executor and agent card,
/// providing a ready-to-use handler for ``A2ARouter`` tests:
///
/// ```swift
/// let handler = MockAgentHandler(executor: .echo())
/// let router = A2ARouter(handler: handler)
/// let result = try await router.route(body: requestData)
/// ```
public final class MockAgentHandler: A2AAgentHandler, @unchecked Sendable {
    private let handler: DefaultRequestHandler

    /// The agent card this handler returns.
    public let card: AgentCard

    /// The task store used by the handler, available for inspection in tests.
    public let store: InMemoryTaskStore

    public init(
        executor: any AgentExecutor = MockAgentExecutor(),
        card: AgentCard = .fixture(),
        store: InMemoryTaskStore = InMemoryTaskStore()
    ) {
        self.card = card
        self.store = store
        self.handler = DefaultRequestHandler(executor: executor, card: card, store: store)
    }

    public func agentCard() async throws -> AgentCard {
        try await handler.agentCard()
    }

    public func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        try await handler.handleSendMessage(request)
    }

    public func handleSendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await handler.handleSendStreamingMessage(request)
    }

    public func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await handler.handleGetTask(request)
    }

    public func handleListTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        try await handler.handleListTasks(request)
    }

    public func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await handler.handleCancelTask(request)
    }
}
