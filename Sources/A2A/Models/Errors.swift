import Foundation

/// A2A protocol error codes mapped to JSON-RPC error codes.
///
/// Includes both A2A-specific errors (task not found, unsupported operation, etc.)
/// and standard JSON-RPC errors (parse error, method not found, etc.).
/// Each code maps to an appropriate HTTP status code via ``httpStatusCode``.
public enum A2AErrorCode: Int, Sendable {
    // A2A-specific errors
    case taskNotFound = -32001
    case taskNotCancelable = -32002
    case pushNotificationNotSupported = -32003
    case unsupportedOperation = -32004
    case contentTypeNotSupported = -32005
    case invalidAgentResponse = -32006
    case extendedAgentCardNotConfigured = -32007
    case extensionSupportRequired = -32008
    case versionNotSupported = -32009

    // Standard JSON-RPC errors
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603

    /// The corresponding HTTP status code.
    public var httpStatusCode: Int {
        switch self {
        case .taskNotFound: return 404
        case .taskNotCancelable: return 409
        case .pushNotificationNotSupported, .unsupportedOperation,
             .extendedAgentCardNotConfigured, .extensionSupportRequired,
             .versionNotSupported: return 400
        case .contentTypeNotSupported: return 415
        case .invalidAgentResponse: return 502
        case .parseError, .invalidRequest, .invalidParams: return 400
        case .methodNotFound: return 404
        case .internalError: return 500
        }
    }

    /// Default error message for each code.
    public var defaultMessage: String {
        switch self {
        case .taskNotFound: return "Task not found"
        case .taskNotCancelable: return "Task is not cancelable"
        case .pushNotificationNotSupported: return "Push notifications not supported"
        case .unsupportedOperation: return "Unsupported operation"
        case .contentTypeNotSupported: return "Content type not supported"
        case .invalidAgentResponse: return "Invalid agent response"
        case .extendedAgentCardNotConfigured: return "Extended agent card not configured"
        case .extensionSupportRequired: return "Extension support required"
        case .versionNotSupported: return "Version not supported"
        case .parseError: return "Parse error"
        case .invalidRequest: return "Invalid request"
        case .methodNotFound: return "Method not found"
        case .invalidParams: return "Invalid params"
        case .internalError: return "Internal error"
        }
    }
}

/// An A2A protocol error.
public struct A2AError: Error, Sendable, CustomStringConvertible {
    /// The error code.
    public let code: A2AErrorCode

    /// Human-readable error message.
    public let message: String

    /// Optional additional error data.
    public let data: JSONValue?

    public init(code: A2AErrorCode, message: String? = nil, data: JSONValue? = nil) {
        self.code = code
        self.message = message ?? code.defaultMessage
        self.data = data
    }

    public var description: String {
        "A2AError(\(code.rawValue)): \(message)"
    }

    // MARK: - Convenience factories

    public static func taskNotFound(taskId: String) -> A2AError {
        A2AError(
            code: .taskNotFound,
            data: .object(["taskId": .string(taskId)])
        )
    }

    public static func taskNotCancelable(taskId: String) -> A2AError {
        A2AError(
            code: .taskNotCancelable,
            data: .object(["taskId": .string(taskId)])
        )
    }

    public static func unsupportedOperation(_ message: String? = nil) -> A2AError {
        A2AError(code: .unsupportedOperation, message: message)
    }

    public static func internalError(_ message: String? = nil) -> A2AError {
        A2AError(code: .internalError, message: message)
    }
}
