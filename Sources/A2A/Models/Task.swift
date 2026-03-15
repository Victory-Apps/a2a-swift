import Foundation

/// The state of a task.
public enum TaskState: String, Codable, Sendable, Hashable {
    case submitted = "TASK_STATE_SUBMITTED"
    case working = "TASK_STATE_WORKING"
    case completed = "TASK_STATE_COMPLETED"
    case failed = "TASK_STATE_FAILED"
    case canceled = "TASK_STATE_CANCELED"
    case inputRequired = "TASK_STATE_INPUT_REQUIRED"
    case rejected = "TASK_STATE_REJECTED"
    case authRequired = "TASK_STATE_AUTH_REQUIRED"

    /// Whether this state is terminal (no further transitions).
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled, .rejected:
            return true
        default:
            return false
        }
    }

    /// Whether this state is an interrupted state requiring input.
    public var isInterrupted: Bool {
        switch self {
        case .inputRequired, .authRequired:
            return true
        default:
            return false
        }
    }
}

/// The current status of a task including state and optional message.
public struct TaskStatus: Codable, Sendable, Hashable {
    /// The current state.
    public var state: TaskState

    /// Optional status message.
    public var message: Message?

    /// When this status was set.
    public var timestamp: String?

    public init(
        state: TaskState,
        message: Message? = nil,
        timestamp: String? = nil
    ) {
        self.state = state
        self.message = message
        self.timestamp = timestamp
    }
}

/// Represents an A2A task.
public struct A2ATask: Codable, Sendable, Hashable {
    /// Unique task identifier (server-generated).
    public var id: String

    /// Context identifier grouping related tasks.
    public var contextId: String?

    /// Current task status.
    public var status: TaskStatus

    /// Output artifacts.
    public var artifacts: [Artifact]?

    /// Interaction history.
    public var history: [Message]?

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    public init(
        id: String = UUID().uuidString,
        contextId: String? = nil,
        status: TaskStatus,
        artifacts: [Artifact]? = nil,
        history: [Message]? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.contextId = contextId
        self.status = status
        self.artifacts = artifacts
        self.history = history
        self.metadata = metadata
    }
}
