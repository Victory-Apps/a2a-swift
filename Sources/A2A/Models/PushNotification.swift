import Foundation

/// Configuration for push notifications on a task.
public struct TaskPushNotificationConfig: Codable, Sendable, Hashable {
    /// Optional tenant identifier.
    public var tenant: String?

    /// Configuration ID.
    public var id: String?

    /// The task ID.
    public var taskId: String?

    /// Webhook URL to receive push notifications.
    public var url: String

    /// Client-provided token for verification.
    public var token: String?

    /// Authentication to use when calling the webhook.
    public var authentication: AuthenticationInfo?

    public init(
        tenant: String? = nil,
        id: String? = nil,
        taskId: String? = nil,
        url: String,
        token: String? = nil,
        authentication: AuthenticationInfo? = nil
    ) {
        self.tenant = tenant
        self.id = id
        self.taskId = taskId
        self.url = url
        self.token = token
        self.authentication = authentication
    }
}

/// Authentication information for push notifications.
public struct AuthenticationInfo: Codable, Sendable, Hashable {
    /// Authentication scheme (e.g. "Bearer", "Basic").
    public var scheme: String

    /// Token or credentials.
    public var credentials: String?

    public init(scheme: String, credentials: String? = nil) {
        self.scheme = scheme
        self.credentials = credentials
    }
}

// MARK: - Push Notification Requests

/// Request to get a push notification config.
public struct GetTaskPushNotificationConfigRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var taskId: String
    public var id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }
}

/// Request to list push notification configs for a task.
public struct ListTaskPushNotificationConfigsRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var taskId: String
    public var pageSize: Int?
    public var pageToken: String?

    public init(tenant: String? = nil, taskId: String, pageSize: Int? = nil, pageToken: String? = nil) {
        self.tenant = tenant
        self.taskId = taskId
        self.pageSize = pageSize
        self.pageToken = pageToken
    }
}

/// Response from listing push notification configs.
public struct ListTaskPushNotificationConfigsResponse: Codable, Sendable, Hashable {
    public var configs: [TaskPushNotificationConfig]
    public var nextPageToken: String?

    public init(configs: [TaskPushNotificationConfig], nextPageToken: String? = nil) {
        self.configs = configs
        self.nextPageToken = nextPageToken
    }
}

/// Request to delete a push notification config.
public struct DeleteTaskPushNotificationConfigRequest: Codable, Sendable, Hashable {
    public var tenant: String?
    public var taskId: String
    public var id: String

    public init(tenant: String? = nil, taskId: String, id: String) {
        self.tenant = tenant
        self.taskId = taskId
        self.id = id
    }
}
