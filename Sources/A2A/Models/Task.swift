import Foundation

/// The state of a task in the A2A protocol lifecycle.
///
/// Tasks progress through states following a defined state machine.
/// Use ``isTerminal`` to check if a task has reached a final state, or
/// ``isInterrupted`` to check if it's waiting for user input.
///
/// ```
/// submitted → working → completed | failed | canceled
///                     → inputRequired → working (on follow-up)
///                     → authRequired → working (on auth)
/// ```
public enum TaskState: String, Codable, Sendable, Hashable {
    /// Unspecified state (default/unknown).
    case unspecified = "TASK_STATE_UNSPECIFIED"
    /// The task has been received but processing hasn't started.
    case submitted = "TASK_STATE_SUBMITTED"
    /// The agent is actively working on the task.
    case working = "TASK_STATE_WORKING"
    /// The task finished successfully.
    case completed = "TASK_STATE_COMPLETED"
    /// The task failed due to an error.
    case failed = "TASK_STATE_FAILED"
    /// The task was canceled by the client.
    case canceled = "TASK_STATE_CANCELED"
    /// The agent needs additional input from the user to continue.
    case inputRequired = "TASK_STATE_INPUT_REQUIRED"
    /// The task was rejected by the agent.
    case rejected = "TASK_STATE_REJECTED"
    /// The agent requires authentication before continuing.
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

/// The central unit of work in the A2A protocol.
///
/// A task is created when a client sends a message to an agent. It tracks the
/// interaction state, conversation history, and output artifacts. Tasks are
/// identified by a unique ``id`` and optionally grouped by ``contextId``.
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
