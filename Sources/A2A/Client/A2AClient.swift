import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A client for communicating with A2A agents over HTTP.
///
/// `A2AClient` handles agent discovery, message sending (synchronous and streaming),
/// task management, and push notification configuration. It works with any
/// A2A-compatible agent regardless of implementation language.
///
/// ```swift
/// let client = A2AClient(baseURL: URL(string: "http://localhost:8080")!)
///
/// // Discover the agent
/// let card = try await client.fetchAgentCard()
///
/// // Send a message
/// let response = try await client.sendMessage(SendMessageRequest(
///     message: Message(role: .user, parts: [.text("Hello!")])
/// ))
///
/// // Stream responses
/// let stream = try await client.sendStreamingMessage(request)
/// for try await event in stream { ... }
/// ```
///
/// Add authentication via ``A2AClientInterceptor`` or the `authHeaders` parameter.
public final class A2AClient: Sendable {
    /// The base URL of the agent.
    public let baseURL: URL

    /// The URLSession used for requests.
    private let session: URLSession

    /// Optional authentication headers to include in requests.
    private let authHeaders: [String: String]

    /// Request/response interceptors.
    private let interceptors: [any A2AClientInterceptor]

    /// JSON encoder configured for A2A.
    private let encoder: JSONEncoder

    /// JSON decoder configured for A2A.
    private let decoder: JSONDecoder

    /// SSE streaming reconnection configuration.
    private let sseConfiguration: SSEConfiguration

    /// Auto-incrementing request ID.
    private let requestIdCounter = RequestIdCounter()

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        authHeaders: [String: String] = [:],
        interceptors: [any A2AClientInterceptor] = [],
        sseConfiguration: SSEConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authHeaders = authHeaders
        self.interceptors = interceptors
        self.sseConfiguration = sseConfiguration
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Agent Card Discovery

    /// Fetches the agent card from the well-known URL.
    public func fetchAgentCard() async throws -> AgentCard {
        let url = baseURL.appendingPathComponent(".well-known/agent-card.json")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)
        return try decoder.decode(AgentCard.self, from: data)
    }

    // MARK: - SendMessage

    /// Sends a message to the agent and waits for a response.
    public func sendMessage(_ params: SendMessageRequest) async throws -> SendMessageResponse {
        try await jsonRPCCall(method: .sendMessage, params: params)
    }

    /// Sends a streaming message and returns an AsyncSequence of stream responses.
    public func sendStreamingMessage(_ params: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let session = try await streamingCallWithSession(method: .sendStreamingMessage, params: params)
        return session.events
    }

    /// Sends a streaming message and returns a ``StreamingSession`` with connection state monitoring.
    public func sendStreamingMessageWithSession(_ params: SendMessageRequest) async throws -> StreamingSession {
        try await streamingCallWithSession(method: .sendStreamingMessage, params: params)
    }

    // MARK: - Task Management

    /// Gets a task by ID.
    public func getTask(_ params: GetTaskRequest) async throws -> A2ATask {
        try await jsonRPCCall(method: .getTask, params: params)
    }

    /// Lists tasks.
    public func listTasks(_ params: ListTasksRequest) async throws -> ListTasksResponse {
        try await jsonRPCCall(method: .listTasks, params: params)
    }

    /// Cancels a task.
    public func cancelTask(_ params: CancelTaskRequest) async throws -> A2ATask {
        try await jsonRPCCall(method: .cancelTask, params: params)
    }

    /// Subscribes to task updates via SSE.
    public func subscribeToTask(_ params: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let session = try await streamingCallWithSession(method: .subscribeToTask, params: params)
        return session.events
    }

    /// Subscribes to task updates and returns a ``StreamingSession`` with connection state monitoring.
    public func subscribeToTaskWithSession(_ params: SubscribeToTaskRequest) async throws -> StreamingSession {
        try await streamingCallWithSession(method: .subscribeToTask, params: params)
    }

    // MARK: - Push Notifications

    /// Creates a push notification config for a task.
    public func createTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await jsonRPCCall(method: .createTaskPushNotificationConfig, params: config)
    }

    /// Gets a push notification config.
    public func getTaskPushNotificationConfig(_ params: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        try await jsonRPCCall(method: .getTaskPushNotificationConfig, params: params)
    }

    /// Lists push notification configs for a task.
    public func listTaskPushNotificationConfigs(_ params: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        try await jsonRPCCall(method: .listTaskPushNotificationConfigs, params: params)
    }

    /// Deletes a push notification config.
    public func deleteTaskPushNotificationConfig(_ params: DeleteTaskPushNotificationConfigRequest) async throws {
        let _: JSONValue = try await jsonRPCCall(method: .deleteTaskPushNotificationConfig, params: params)
    }

    // MARK: - Extended Agent Card

    /// Gets the extended agent card.
    public func getExtendedAgentCard(_ params: GetExtendedAgentCardRequest = GetExtendedAgentCardRequest()) async throws -> AgentCard {
        try await jsonRPCCall(method: .getExtendedAgentCard, params: params)
    }

    // MARK: - Private Helpers

    private func jsonRPCCall<Params: Codable & Sendable, Result: Codable & Sendable>(
        method: A2AMethod,
        params: Params
    ) async throws -> Result {
        let id = requestIdCounter.next()
        let rpcRequest = JSONRPCRequest(id: .int(id), method: method, params: params)

        var httpRequest = URLRequest(url: baseURL)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("1.0", forHTTPHeaderField: "A2A-Version")
        applyHeaders(to: &httpRequest)
        httpRequest.httpBody = try encoder.encode(rpcRequest)

        // Run before interceptors
        for interceptor in interceptors {
            try await interceptor.before(request: &httpRequest, method: method)
        }

        var (data, response) = try await session.data(for: httpRequest)
        try validateHTTPResponse(response)

        // Run after interceptors
        for interceptor in interceptors {
            data = try await interceptor.after(response: response, data: data, method: method)
        }

        let rpcResponse = try decoder.decode(JSONRPCResponse<Result>.self, from: data)
        if let error = rpcResponse.error {
            throw A2AError(
                code: A2AErrorCode(rawValue: error.code) ?? .internalError,
                message: error.message,
                data: error.data
            )
        }
        guard let result = rpcResponse.result else {
            throw A2AError(code: .internalError, message: "Empty result in JSON-RPC response")
        }
        return result
    }

    private func streamingCallWithSession<Params: Codable & Sendable>(
        method: A2AMethod,
        params: Params
    ) async throws -> StreamingSession {
        let id = requestIdCounter.next()
        let rpcRequest = JSONRPCRequest(id: .int(id), method: method, params: params)

        var httpRequest = URLRequest(url: baseURL)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        httpRequest.setValue("1.0", forHTTPHeaderField: "A2A-Version")
        applyHeaders(to: &httpRequest)
        httpRequest.httpBody = try encoder.encode(rpcRequest)

        // Run before interceptors
        for interceptor in interceptors {
            try await interceptor.before(request: &httpRequest, method: method)
        }

        // Capture as immutable for use in closures
        let baseRequest = httpRequest
        let decoder = self.decoder
        let urlSession = self.session
        let sseConfig = self.sseConfiguration

        let (connectionStateStream, connectionStateContinuation) = AsyncStream<ConnectionState>.makeStream()

        #if canImport(FoundationNetworking)
        // Linux: FoundationNetworking doesn't support URLSession.bytes,
        // so we fall back to fetching the complete response and parsing SSE lines.
        // Reconnection is supported via retry on connection failure.
        let events = AsyncThrowingStream<StreamResponse, Error> { continuation in
            let task = Task {
                var parser = SSELineParser()
                var attempt = 0

                retryLoop: while true {
                    do {
                        var reconnectRequest = baseRequest
                        if let lastId = parser.lastEventId {
                            reconnectRequest.setValue(lastId, forHTTPHeaderField: "Last-Event-ID")
                        }

                        let (data, response) = try await urlSession.data(for: reconnectRequest)
                        try self.validateHTTPResponse(response)

                        if attempt > 0 {
                            connectionStateContinuation.yield(.connected)
                        }
                        attempt = 0

                        let text = String(data: data, encoding: .utf8) ?? ""
                        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                            let field = parser.parse(line: line)
                            switch field {
                            case .data(let jsonString):
                                guard !jsonString.isEmpty else { continue }
                                guard let jsonData = jsonString.data(using: .utf8) else { continue }

                                let rpcResponse = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: jsonData)
                                if let error = rpcResponse.error {
                                    continuation.finish(throwing: A2AError(
                                        code: A2AErrorCode(rawValue: error.code) ?? .internalError,
                                        message: error.message,
                                        data: error.data
                                    ))
                                    connectionStateContinuation.finish()
                                    return
                                }
                                if let result = rpcResponse.result {
                                    continuation.yield(result)
                                }
                            default:
                                break
                            }
                        }
                        // Normal completion
                        continuation.finish()
                        connectionStateContinuation.finish()
                        return

                    } catch let error as A2AError {
                        // JSON-RPC errors are not retryable
                        continuation.finish(throwing: error)
                        connectionStateContinuation.yield(.disconnected(error))
                        connectionStateContinuation.finish()
                        return
                    } catch {
                        guard !Task.isCancelled else {
                            continuation.finish(throwing: error)
                            connectionStateContinuation.finish()
                            return
                        }

                        attempt += 1
                        if attempt > sseConfig.maxRetries {
                            continuation.finish(throwing: error)
                            connectionStateContinuation.yield(.disconnected(error))
                            connectionStateContinuation.finish()
                            return
                        }

                        connectionStateContinuation.yield(.reconnecting(attempt: attempt, maxAttempts: sseConfig.maxRetries))
                        let delay = parser.serverRetryInterval ?? sseConfig.delay(forAttempt: attempt - 1)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue retryLoop
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                connectionStateContinuation.finish()
            }
        }

        #else
        let events = AsyncThrowingStream<StreamResponse, Error> { continuation in
            let task = Task {
                var parser = SSELineParser()
                var lastSeenId: Int?
                var attempt = 0

                retryLoop: while true {
                    do {
                        guard !Task.isCancelled else {
                            continuation.finish()
                            connectionStateContinuation.finish()
                            return
                        }

                        var reconnectRequest = baseRequest
                        if let lastId = parser.lastEventId {
                            reconnectRequest.setValue(lastId, forHTTPHeaderField: "Last-Event-ID")
                        }

                        let (bytes, response) = try await urlSession.bytes(for: reconnectRequest)
                        try self.validateHTTPResponse(response)

                        if attempt > 0 {
                            connectionStateContinuation.yield(.connected)
                        }
                        attempt = 0

                        for try await line in bytes.lines {
                            guard !Task.isCancelled else { break }

                            let field = parser.parse(line: line)
                            switch field {
                            case .data(let jsonString):
                                guard !jsonString.isEmpty else { continue }
                                guard let jsonData = jsonString.data(using: .utf8) else { continue }

                                // Deduplicate after reconnect
                                if let lastId = parser.lastEventId, let idNum = Int(lastId),
                                   let seen = lastSeenId, idNum <= seen {
                                    continue
                                }
                                if let lastId = parser.lastEventId, let idNum = Int(lastId) {
                                    lastSeenId = idNum
                                }

                                let rpcResponse = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: jsonData)
                                if let error = rpcResponse.error {
                                    continuation.finish(throwing: A2AError(
                                        code: A2AErrorCode(rawValue: error.code) ?? .internalError,
                                        message: error.message,
                                        data: error.data
                                    ))
                                    connectionStateContinuation.finish()
                                    return
                                }
                                if let result = rpcResponse.result {
                                    continuation.yield(result)
                                }
                            default:
                                break
                            }
                        }
                        // Normal completion
                        continuation.finish()
                        connectionStateContinuation.finish()
                        return

                    } catch let error as A2AError {
                        // JSON-RPC errors are not retryable
                        continuation.finish(throwing: error)
                        connectionStateContinuation.yield(.disconnected(error))
                        connectionStateContinuation.finish()
                        return
                    } catch {
                        guard !Task.isCancelled else {
                            continuation.finish(throwing: error)
                            connectionStateContinuation.finish()
                            return
                        }

                        attempt += 1
                        if attempt > sseConfig.maxRetries {
                            continuation.finish(throwing: error)
                            connectionStateContinuation.yield(.disconnected(error))
                            connectionStateContinuation.finish()
                            return
                        }

                        connectionStateContinuation.yield(.reconnecting(attempt: attempt, maxAttempts: sseConfig.maxRetries))
                        let delay = parser.serverRetryInterval ?? sseConfig.delay(forAttempt: attempt - 1)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue retryLoop
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                connectionStateContinuation.finish()
            }
        }
        #endif

        connectionStateContinuation.yield(.connected)
        return StreamingSession(events: events, connectionState: connectionStateStream)
    }

    private func applyHeaders(to request: inout URLRequest) {
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError(code: .internalError, message: "Invalid HTTP response")
        }
        // We don't throw on non-2xx here because JSON-RPC errors come in the body
        // But we do throw on server errors that don't return JSON-RPC
        if httpResponse.statusCode >= 500 {
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            if !contentType.contains("json") {
                throw A2AError(code: .internalError, message: "Server error: \(httpResponse.statusCode)")
            }
        }
    }
}

/// Thread-safe auto-incrementing counter for JSON-RPC request IDs.
private final class RequestIdCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
        return _value
    }
}
