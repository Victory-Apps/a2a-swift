import Foundation

// MARK: - SendMessage

/// Configuration for a SendMessage request.
public struct SendMessageConfiguration: Codable, Sendable, Hashable {
    /// Accepted output MIME types.
    public var acceptedOutputModes: [String]?

    /// Push notification configuration for this task.
    public var taskPushNotificationConfig: TaskPushNotificationConfig?

    /// Number of history messages to include in the response.
    public var historyLength: Int?

    /// If true, the server returns immediately without waiting for completion.
    public var returnImmediately: Bool?

    public init(
        acceptedOutputModes: [String]? = nil,
        taskPushNotificationConfig: TaskPushNotificationConfig? = nil,
        historyLength: Int? = nil,
        returnImmediately: Bool? = nil
    ) {
        self.acceptedOutputModes = acceptedOutputModes
        self.taskPushNotificationConfig = taskPushNotificationConfig
        self.historyLength = historyLength
        self.returnImmediately = returnImmediately
    }
}

/// Request to send a message to an agent.
public struct SendMessageRequest: Codable, Sendable, Hashable {
    /// Optional tenant identifier.
    public var tenant: String?

    /// The message to send.
    public var message: Message

    /// Optional configuration.
    public var configuration: SendMessageConfiguration?

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    public init(
        tenant: String? = nil,
        message: Message,
        configuration: SendMessageConfiguration? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.tenant = tenant
        self.message = message
        self.configuration = configuration
        self.metadata = metadata
    }
}

// MARK: - GetTask

/// Request to get a task by ID.
public struct GetTaskRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var id: String
    public var historyLength: Int?

    public init(tenant: String? = nil, id: String, historyLength: Int? = nil) {
        self.tenant = tenant
        self.id = id
        self.historyLength = historyLength
    }
}

// MARK: - ListTasks

/// Request to list tasks.
public struct ListTasksRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var contextId: String?
    public var status: TaskState?
    public var pageSize: Int?
    public var pageToken: String?
    public var historyLength: Int?
    public var statusTimestampAfter: String?
    public var includeArtifacts: Bool?

    public init(
        tenant: String? = nil,
        contextId: String? = nil,
        status: TaskState? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil,
        historyLength: Int? = nil,
        statusTimestampAfter: String? = nil,
        includeArtifacts: Bool? = nil
    ) {
        self.tenant = tenant
        self.contextId = contextId
        self.status = status
        self.pageSize = pageSize
        self.pageToken = pageToken
        self.historyLength = historyLength
        self.statusTimestampAfter = statusTimestampAfter
        self.includeArtifacts = includeArtifacts
    }
}

/// Response from ListTasks.
public struct ListTasksResponse: Codable, Sendable, Hashable {
    public var tasks: [A2ATask]
    public var nextPageToken: String
    public var pageSize: Int
    public var totalSize: Int

    public init(tasks: [A2ATask], nextPageToken: String = "", pageSize: Int, totalSize: Int) {
        self.tasks = tasks
        self.nextPageToken = nextPageToken
        self.pageSize = pageSize
        self.totalSize = totalSize
    }
}

// MARK: - CancelTask

/// Request to cancel a task.
public struct CancelTaskRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var id: String
    public var metadata: [String: JSONValue]?

    public init(tenant: String? = nil, id: String, metadata: [String: JSONValue]? = nil) {
        self.tenant = tenant
        self.id = id
        self.metadata = metadata
    }
}

// MARK: - SubscribeToTask

/// Request to subscribe to task updates via SSE.
public struct SubscribeToTaskRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var id: String

    public init(tenant: String? = nil, id: String) {
        self.tenant = tenant
        self.id = id
    }
}

// MARK: - GetExtendedAgentCard

/// Request for the extended agent card.
public struct GetExtendedAgentCardRequest: Codable, Sendable, Hashable {
    public var tenant: String?

    public init(tenant: String? = nil) {
        self.tenant = tenant
    }
}
