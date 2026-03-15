import Foundation

/// Event sent when a task's status is updated.
public struct TaskStatusUpdateEvent: Codable, Sendable, Hashable {
    /// The task ID.
    public var taskId: String

    /// The context ID.
    public var contextId: String

    /// The updated status.
    public var status: TaskStatus

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    public init(
        taskId: String,
        contextId: String,
        status: TaskStatus,
        metadata: [String: JSONValue]? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.status = status
        self.metadata = metadata
    }
}

/// Event sent when a task artifact is updated.
public struct TaskArtifactUpdateEvent: Codable, Sendable, Hashable {
    /// The task ID.
    public var taskId: String

    /// The context ID.
    public var contextId: String

    /// The artifact update.
    public var artifact: Artifact

    /// Whether to append to a previous artifact with the same ID.
    public var append: Bool?

    /// Whether this is the final chunk for this artifact.
    public var lastChunk: Bool?

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    public init(
        taskId: String,
        contextId: String,
        artifact: Artifact,
        append: Bool? = nil,
        lastChunk: Bool? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.taskId = taskId
        self.contextId = contextId
        self.artifact = artifact
        self.append = append
        self.lastChunk = lastChunk
        self.metadata = metadata
    }
}

/// A streaming response that can contain one of several payload types.
public enum StreamResponse: Codable, Sendable, Hashable {
    case task(A2ATask)
    case message(Message)
    case statusUpdate(TaskStatusUpdateEvent)
    case artifactUpdate(TaskArtifactUpdateEvent)

    private enum CodingKeys: String, CodingKey {
        case task
        case message
        case statusUpdate
        case artifactUpdate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let task = try container.decodeIfPresent(A2ATask.self, forKey: .task) {
            self = .task(task)
            return
        }
        if let message = try container.decodeIfPresent(Message.self, forKey: .message) {
            self = .message(message)
            return
        }
        if let statusUpdate = try container.decodeIfPresent(TaskStatusUpdateEvent.self, forKey: .statusUpdate) {
            self = .statusUpdate(statusUpdate)
            return
        }
        if let artifactUpdate = try container.decodeIfPresent(TaskArtifactUpdateEvent.self, forKey: .artifactUpdate) {
            self = .artifactUpdate(artifactUpdate)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "StreamResponse must contain one of: task, message, statusUpdate, artifactUpdate")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        case .statusUpdate(let event):
            try container.encode(event, forKey: .statusUpdate)
        case .artifactUpdate(let event):
            try container.encode(event, forKey: .artifactUpdate)
        }
    }
}

/// Response from SendMessage, which can be either a Task or a Message.
public enum SendMessageResponse: Codable, Sendable, Hashable {
    case task(A2ATask)
    case message(Message)

    private enum CodingKeys: String, CodingKey {
        case task
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let task = try container.decodeIfPresent(A2ATask.self, forKey: .task) {
            self = .task(task)
            return
        }
        if let message = try container.decodeIfPresent(Message.self, forKey: .message) {
            self = .message(message)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "SendMessageResponse must contain one of: task, message")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .task(let task):
            try container.encode(task, forKey: .task)
        case .message(let message):
            try container.encode(message, forKey: .message)
        }
    }
}
