import Foundation

/// A mock A2A client for testing without network requests.
///
/// Configure responses with `set*()` methods, then call the same methods
/// as ``A2AClient``. Inspect recorded calls after the test:
///
/// ```swift
/// let client = MockA2AClient()
/// await client.setAgentCard(.fixture(name: "My Agent"))
///
/// let card = try await client.fetchAgentCard()
/// // card.name == "My Agent"
///
/// let count = await client.fetchAgentCardCallCount
/// // count == 1
/// ```
public final class MockA2AClient: Sendable {
    private let state: StateActor

    public init() {
        self.state = StateActor()
    }

    // MARK: - Configuration

    /// Sets the agent card returned by ``fetchAgentCard()``.
    public func setAgentCard(_ card: AgentCard) async {
        await state.setAgentCard(card)
    }

    /// Sets the response returned by ``sendMessage(_:)``.
    public func setSendMessageResponse(_ response: SendMessageResponse) async {
        await state.setSendMessageResponse(response)
    }

    /// Sets the events yielded by ``sendStreamingMessage(_:)``.
    public func setStreamingResponses(_ responses: [StreamResponse]) async {
        await state.setStreamingResponses(responses)
    }

    /// Sets the task returned by ``getTask(_:)``.
    public func setGetTaskResponse(_ task: A2ATask) async {
        await state.setGetTaskResponse(task)
    }

    /// Sets the response returned by ``listTasks(_:)``.
    public func setListTasksResponse(_ response: ListTasksResponse) async {
        await state.setListTasksResponse(response)
    }

    /// Sets the task returned by ``cancelTask(_:)``.
    public func setCancelTaskResponse(_ task: A2ATask) async {
        await state.setCancelTaskResponse(task)
    }

    /// When set, all methods throw this error instead of returning configured responses.
    public func setError(_ error: Error?) async {
        await state.setError(error)
    }

    // MARK: - Client API

    /// Returns the configured agent card.
    public func fetchAgentCard() async throws -> AgentCard {
        try await state.fetchAgentCard()
    }

    /// Returns the configured send message response.
    public func sendMessage(_ params: SendMessageRequest) async throws -> SendMessageResponse {
        try await state.sendMessage(params)
    }

    /// Returns a stream yielding the configured streaming responses.
    public func sendStreamingMessage(_ params: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        try await state.sendStreamingMessage(params)
    }

    /// Returns the configured task.
    public func getTask(_ params: GetTaskRequest) async throws -> A2ATask {
        try await state.getTask(params)
    }

    /// Returns the configured list tasks response.
    public func listTasks(_ params: ListTasksRequest) async throws -> ListTasksResponse {
        try await state.listTasks(params)
    }

    /// Returns the configured cancel task response.
    public func cancelTask(_ params: CancelTaskRequest) async throws -> A2ATask {
        try await state.cancelTask(params)
    }

    // MARK: - Inspection

    /// Number of times ``fetchAgentCard()`` was called.
    public var fetchAgentCardCallCount: Int {
        get async { await state.fetchAgentCardCallCount }
    }

    /// Number of times ``sendMessage(_:)`` was called.
    public var sendMessageCallCount: Int {
        get async { await state.sendMessageCallCount }
    }

    /// The most recent request passed to ``sendMessage(_:)``.
    public var lastSendMessageRequest: SendMessageRequest? {
        get async { await state.lastSendMessageRequest }
    }

    /// Number of times ``sendStreamingMessage(_:)`` was called.
    public var sendStreamingMessageCallCount: Int {
        get async { await state.sendStreamingMessageCallCount }
    }

    /// Number of times ``getTask(_:)`` was called.
    public var getTaskCallCount: Int {
        get async { await state.getTaskCallCount }
    }

    /// Number of times ``cancelTask(_:)`` was called.
    public var cancelTaskCallCount: Int {
        get async { await state.cancelTaskCallCount }
    }

    /// Clears all recorded calls and configured responses.
    public func reset() async {
        await state.reset()
    }
}

// MARK: - Internal Actor

extension MockA2AClient {
    actor StateActor {
        var agentCard: AgentCard?
        var sendMessageResponse: SendMessageResponse?
        var streamingResponses: [StreamResponse] = []
        var getTaskResponse: A2ATask?
        var listTasksResponse: ListTasksResponse?
        var cancelTaskResponse: A2ATask?
        var error: Error?

        var fetchAgentCardCallCount = 0
        var sendMessageCalls: [SendMessageRequest] = []
        var sendStreamingMessageCalls: [SendMessageRequest] = []
        var getTaskCalls: [GetTaskRequest] = []
        var cancelTaskCalls: [CancelTaskRequest] = []

        var sendMessageCallCount: Int { sendMessageCalls.count }
        var sendStreamingMessageCallCount: Int { sendStreamingMessageCalls.count }
        var getTaskCallCount: Int { getTaskCalls.count }
        var cancelTaskCallCount: Int { cancelTaskCalls.count }
        var lastSendMessageRequest: SendMessageRequest? { sendMessageCalls.last }

        // Configuration
        func setAgentCard(_ card: AgentCard) { agentCard = card }
        func setSendMessageResponse(_ response: SendMessageResponse) { sendMessageResponse = response }
        func setStreamingResponses(_ responses: [StreamResponse]) { streamingResponses = responses }
        func setGetTaskResponse(_ task: A2ATask) { getTaskResponse = task }
        func setListTasksResponse(_ response: ListTasksResponse) { listTasksResponse = response }
        func setCancelTaskResponse(_ task: A2ATask) { cancelTaskResponse = task }
        func setError(_ err: Error?) { error = err }

        func reset() {
            agentCard = nil
            sendMessageResponse = nil
            streamingResponses = []
            getTaskResponse = nil
            listTasksResponse = nil
            cancelTaskResponse = nil
            error = nil
            fetchAgentCardCallCount = 0
            sendMessageCalls = []
            sendStreamingMessageCalls = []
            getTaskCalls = []
            cancelTaskCalls = []
        }

        // Client methods
        func fetchAgentCard() throws -> AgentCard {
            fetchAgentCardCallCount += 1
            if let error { throw error }
            guard let agentCard else {
                throw MockA2AClientError.notConfigured("agentCard")
            }
            return agentCard
        }

        func sendMessage(_ params: SendMessageRequest) throws -> SendMessageResponse {
            sendMessageCalls.append(params)
            if let error { throw error }
            guard let sendMessageResponse else {
                throw MockA2AClientError.notConfigured("sendMessageResponse")
            }
            return sendMessageResponse
        }

        func sendStreamingMessage(_ params: SendMessageRequest) throws -> AsyncThrowingStream<StreamResponse, Error> {
            sendStreamingMessageCalls.append(params)
            if let error { throw error }
            let responses = streamingResponses
            return AsyncThrowingStream { continuation in
                for response in responses {
                    continuation.yield(response)
                }
                continuation.finish()
            }
        }

        func getTask(_ params: GetTaskRequest) throws -> A2ATask {
            getTaskCalls.append(params)
            if let error { throw error }
            guard let getTaskResponse else {
                throw MockA2AClientError.notConfigured("getTaskResponse")
            }
            return getTaskResponse
        }

        func listTasks(_ params: ListTasksRequest) throws -> ListTasksResponse {
            if let error { throw error }
            guard let listTasksResponse else {
                throw MockA2AClientError.notConfigured("listTasksResponse")
            }
            return listTasksResponse
        }

        func cancelTask(_ params: CancelTaskRequest) throws -> A2ATask {
            cancelTaskCalls.append(params)
            if let error { throw error }
            guard let cancelTaskResponse else {
                throw MockA2AClientError.notConfigured("cancelTaskResponse")
            }
            return cancelTaskResponse
        }
    }
}

/// Error thrown when a ``MockA2AClient`` method is called without configuring a response.
public struct MockA2AClientError: Error, CustomStringConvertible {
    public let description: String

    static func notConfigured(_ property: String) -> MockA2AClientError {
        MockA2AClientError(description: "MockA2AClient.\(property) not configured. Call set\(property.prefix(1).uppercased() + property.dropFirst())() before using this method.")
    }
}
