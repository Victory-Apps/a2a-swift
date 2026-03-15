import Foundation

/// Protocol that defines the handler for A2A agent operations.
/// Implement this protocol to create your own A2A agent.
public protocol A2AAgentHandler: Sendable {
    /// Returns the agent card describing this agent.
    func agentCard() async throws -> AgentCard

    /// Handles a SendMessage request.
    func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse

    /// Handles a SendStreamingMessage request. Returns an async stream of responses.
    func handleSendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Gets a task by ID.
    func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask

    /// Lists tasks.
    func handleListTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse

    /// Cancels a task.
    func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask

    /// Subscribes to task updates.
    func handleSubscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error>

    /// Creates a push notification config.
    func handleCreateTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig

    /// Gets a push notification config.
    func handleGetTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig

    /// Lists push notification configs.
    func handleListTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse

    /// Deletes a push notification config.
    func handleDeleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws

    /// Gets the extended agent card (if supported).
    func handleGetExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard
}

// MARK: - Default Implementations

extension A2AAgentHandler {
    public func handleSendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        throw A2AError.unsupportedOperation("Streaming not supported")
    }

    public func handleListTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        throw A2AError.unsupportedOperation("ListTasks not supported")
    }

    public func handleSubscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        throw A2AError.unsupportedOperation("SubscribeToTask not supported")
    }

    public func handleCreateTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        throw A2AError(code: .pushNotificationNotSupported)
    }

    public func handleGetTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        throw A2AError(code: .pushNotificationNotSupported)
    }

    public func handleListTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        throw A2AError(code: .pushNotificationNotSupported)
    }

    public func handleDeleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws {
        throw A2AError(code: .pushNotificationNotSupported)
    }

    public func handleGetExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard {
        throw A2AError(code: .extendedAgentCardNotConfigured)
    }
}

/// Routes incoming A2A JSON-RPC requests to the appropriate handler method.
/// This can be integrated with any HTTP server framework.
public struct A2ARouter: Sendable {
    private let handler: any A2AAgentHandler
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(handler: any A2AAgentHandler) {
        self.handler = handler
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// The result of routing a request - either a single response or a stream.
    public enum RouteResult: Sendable {
        /// A single JSON response body.
        case response(Data)
        /// A streaming SSE response.
        case stream(AsyncThrowingStream<Data, Error>)
        /// Agent card JSON (for well-known endpoint).
        case agentCard(Data)
    }

    /// Handles the well-known agent card request.
    public func handleAgentCardRequest() async throws -> Data {
        let card = try await handler.agentCard()
        return try encoder.encode(card)
    }

    /// Routes a JSON-RPC request body and returns the appropriate response.
    public func route(body: Data) async throws -> RouteResult {
        let rawRequest: RawJSONRPCRequest
        do {
            rawRequest = try decoder.decode(RawJSONRPCRequest.self, from: body)
        } catch {
            let errorResponse = JSONRPCResponse<JSONValue>(
                id: nil,
                error: JSONRPCError(code: A2AErrorCode.parseError.rawValue, message: "Parse error")
            )
            return .response(try encoder.encode(errorResponse))
        }

        guard let method = A2AMethod(rawValue: rawRequest.method) else {
            let errorResponse = JSONRPCResponse<JSONValue>(
                id: rawRequest.id,
                error: JSONRPCError(code: A2AErrorCode.methodNotFound.rawValue, message: "Method not found: \(rawRequest.method)")
            )
            return .response(try encoder.encode(errorResponse))
        }

        let requestId = rawRequest.id

        // Re-encode params for typed decoding
        let paramsData: Data?
        if let params = rawRequest.params {
            paramsData = try encoder.encode(params)
        } else {
            paramsData = nil
        }

        do {
            switch method {
            case .sendMessage:
                let params: SendMessageRequest = try decodeParams(paramsData)
                let result = try await handler.handleSendMessage(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .sendStreamingMessage:
                let params: SendMessageRequest = try decodeParams(paramsData)
                let stream = try await handler.handleSendStreamingMessage(params)
                return .stream(wrapStreamAsSSE(id: requestId, stream: stream))

            case .getTask:
                let params: GetTaskRequest = try decodeParams(paramsData)
                let result = try await handler.handleGetTask(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .listTasks:
                let params: ListTasksRequest = try decodeParams(paramsData)
                let result = try await handler.handleListTasks(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .cancelTask:
                let params: CancelTaskRequest = try decodeParams(paramsData)
                let result = try await handler.handleCancelTask(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .subscribeToTask:
                let params: SubscribeToTaskRequest = try decodeParams(paramsData)
                let stream = try await handler.handleSubscribeToTask(params)
                return .stream(wrapStreamAsSSE(id: requestId, stream: stream))

            case .createTaskPushNotificationConfig:
                let params: TaskPushNotificationConfig = try decodeParams(paramsData)
                let result = try await handler.handleCreateTaskPushNotificationConfig(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .getTaskPushNotificationConfig:
                let params: GetTaskPushNotificationConfigRequest = try decodeParams(paramsData)
                let result = try await handler.handleGetTaskPushNotificationConfig(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .listTaskPushNotificationConfigs:
                let params: ListTaskPushNotificationConfigsRequest = try decodeParams(paramsData)
                let result = try await handler.handleListTaskPushNotificationConfigs(params)
                return .response(try encodeResult(id: requestId, result: result))

            case .deleteTaskPushNotificationConfig:
                let params: DeleteTaskPushNotificationConfigRequest = try decodeParams(paramsData)
                try await handler.handleDeleteTaskPushNotificationConfig(params)
                return .response(try encodeResult(id: requestId, result: JSONValue.null))

            case .getExtendedAgentCard:
                let params: GetExtendedAgentCardRequest = try decodeParams(paramsData)
                let result = try await handler.handleGetExtendedAgentCard(params)
                return .response(try encodeResult(id: requestId, result: result))
            }
        } catch let error as A2AError {
            let errorResponse = JSONRPCResponse<JSONValue>(
                id: requestId,
                error: JSONRPCError(error)
            )
            return .response(try encoder.encode(errorResponse))
        } catch {
            let errorResponse = JSONRPCResponse<JSONValue>(
                id: requestId,
                error: JSONRPCError(code: A2AErrorCode.internalError.rawValue, message: error.localizedDescription)
            )
            return .response(try encoder.encode(errorResponse))
        }
    }

    // MARK: - Private Helpers

    private func decodeParams<T: Decodable>(_ data: Data?) throws -> T {
        guard let data = data else {
            throw A2AError(code: .invalidParams, message: "Missing params")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw A2AError(code: .invalidParams, message: "Invalid params: \(error.localizedDescription)")
        }
    }

    private func encodeResult<T: Codable & Sendable>(id: JSONRPCId?, result: T) throws -> Data {
        let response = JSONRPCResponse(id: id ?? .int(0), result: result)
        return try encoder.encode(response)
    }

    private func wrapStreamAsSSE(id: JSONRPCId?, stream: AsyncThrowingStream<StreamResponse, Error>) -> AsyncThrowingStream<Data, Error> {
        let encoder = self.encoder
        let resolvedId = id ?? .int(0)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in stream {
                        guard !Task.isCancelled else { break }
                        let response = JSONRPCResponse(id: resolvedId, result: event)
                        let jsonData = try encoder.encode(response)
                        guard let jsonString = String(data: jsonData, encoding: .utf8) else { continue }
                        let sseData = "data: \(jsonString)\n\n".data(using: .utf8)!
                        continuation.yield(sseData)
                    }
                    continuation.finish()
                } catch let error as A2AError {
                    let errorResponse = JSONRPCResponse<JSONValue>(
                        id: resolvedId,
                        error: JSONRPCError(error)
                    )
                    if let errorData = try? encoder.encode(errorResponse),
                       let errorString = String(data: errorData, encoding: .utf8) {
                        let sseData = "data: \(errorString)\n\n".data(using: .utf8)!
                        continuation.yield(sseData)
                    }
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
