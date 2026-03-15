import Foundation

/// JSON-RPC 2.0 request identifier (either integer or string).
public enum JSONRPCId: Codable, Sendable, Hashable {
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                JSONRPCId.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or String for JSON-RPC id")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

/// A2A JSON-RPC method names.
public enum A2AMethod: String, Codable, Sendable {
    case sendMessage = "SendMessage"
    case sendStreamingMessage = "SendStreamingMessage"
    case getTask = "GetTask"
    case listTasks = "ListTasks"
    case cancelTask = "CancelTask"
    case subscribeToTask = "SubscribeToTask"
    case createTaskPushNotificationConfig = "CreateTaskPushNotificationConfig"
    case getTaskPushNotificationConfig = "GetTaskPushNotificationConfig"
    case listTaskPushNotificationConfigs = "ListTaskPushNotificationConfigs"
    case deleteTaskPushNotificationConfig = "DeleteTaskPushNotificationConfig"
    case getExtendedAgentCard = "GetExtendedAgentCard"
}

/// A JSON-RPC 2.0 request.
public struct JSONRPCRequest<Params: Codable & Sendable>: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId
    public let method: String
    public let params: Params?

    public init(id: JSONRPCId, method: A2AMethod, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method.rawValue
        self.params = params
    }

    public init(id: JSONRPCId, method: String, params: Params? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

/// A JSON-RPC 2.0 error object.
public struct JSONRPCError: Codable, Sendable, Hashable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    /// Creates a JSON-RPC error from an A2AError.
    public init(_ error: A2AError) {
        self.code = error.code.rawValue
        self.message = error.message
        self.data = error.data
    }
}

/// A JSON-RPC 2.0 response.
public struct JSONRPCResponse<Result: Codable & Sendable>: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let result: Result?
    public let error: JSONRPCError?

    public init(id: JSONRPCId, result: Result) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: JSONRPCId?, error: JSONRPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }

    /// Whether this response indicates success.
    public var isSuccess: Bool {
        error == nil && result != nil
    }
}

/// A raw JSON-RPC request used for initial parsing before dispatching.
public struct RawJSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONRPCId?
    public let method: String
    public let params: JSONValue?
}
