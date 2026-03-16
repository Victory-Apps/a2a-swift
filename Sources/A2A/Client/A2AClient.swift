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

    /// Auto-incrementing request ID.
    private let requestIdCounter = RequestIdCounter()

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        authHeaders: [String: String] = [:],
        interceptors: [any A2AClientInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authHeaders = authHeaders
        self.interceptors = interceptors
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
        try await streamingCall(method: .sendStreamingMessage, params: params)
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
        try await streamingCall(method: .subscribeToTask, params: params)
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

    private func streamingCall<Params: Codable & Sendable>(
        method: A2AMethod,
        params: Params
    ) async throws -> AsyncThrowingStream<StreamResponse, Error> {
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

        let decoder = self.decoder

        #if canImport(FoundationNetworking)
        // Linux: FoundationNetworking doesn't support URLSession.bytes,
        // so we fall back to fetching the complete response and parsing SSE lines.
        let (data, response) = try await session.data(for: httpRequest)
        try validateHTTPResponse(response)

        return AsyncThrowingStream { continuation in
            do {
                let text = String(data: data, encoding: .utf8) ?? ""
                for line in text.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("data:") else { continue }

                    let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    guard !jsonString.isEmpty else { continue }
                    guard let jsonData = jsonString.data(using: .utf8) else { continue }

                    let rpcResponse = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: jsonData)
                    if let error = rpcResponse.error {
                        continuation.finish(throwing: A2AError(
                            code: A2AErrorCode(rawValue: error.code) ?? .internalError,
                            message: error.message,
                            data: error.data
                        ))
                        return
                    }
                    if let result = rpcResponse.result {
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        #else
        let (bytes, response) = try await session.bytes(for: httpRequest)
        try validateHTTPResponse(response)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        // SSE format: "data: {json}\n"
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data:") else { continue }

                        let jsonString = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard !jsonString.isEmpty else { continue }
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }

                        // Parse JSON-RPC response wrapping the StreamResponse
                        let rpcResponse = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: jsonData)
                        if let error = rpcResponse.error {
                            continuation.finish(throwing: A2AError(
                                code: A2AErrorCode(rawValue: error.code) ?? .internalError,
                                message: error.message,
                                data: error.data
                            ))
                            return
                        }
                        if let result = rpcResponse.result {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        #endif
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
