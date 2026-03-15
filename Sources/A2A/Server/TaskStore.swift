import Foundation

/// Protocol for persisting and retrieving A2A tasks.
/// Implement this protocol to provide custom storage backends (e.g., database, Redis).
public protocol TaskStore: Sendable {
    /// Creates a new task and stores it.
    func createTask(contextId: String?, status: TaskStatus, metadata: [String: JSONValue]?) async throws -> A2ATask

    /// Gets a task by ID, optionally limiting history length.
    func getTask(id: String, historyLength: Int?) async throws -> A2ATask

    /// Updates a task's status.
    func updateTaskStatus(id: String, status: TaskStatus) async throws -> A2ATask

    /// Adds a message to a task's history.
    func addMessage(taskId: String, message: Message) async throws -> A2ATask

    /// Adds an artifact to a task.
    func addArtifact(taskId: String, artifact: Artifact) async throws -> A2ATask

    /// Appends content to an existing artifact (for streaming artifact chunks).
    func appendToArtifact(taskId: String, artifactId: String, parts: [Part]) async throws -> A2ATask

    /// Lists tasks with optional filters and pagination.
    func listTasks(
        contextId: String?,
        state: TaskState?,
        pageSize: Int,
        pageToken: String?,
        historyLength: Int?,
        includeArtifacts: Bool
    ) async throws -> ListTasksResponse

    /// Cancels a task.
    func cancelTask(id: String) async throws -> A2ATask

    // MARK: - Push Notification Configs

    /// Creates or updates a push notification config.
    func createPushConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig

    /// Gets a push notification config.
    func getPushConfig(taskId: String, configId: String) async throws -> TaskPushNotificationConfig

    /// Lists push notification configs for a task.
    func listPushConfigs(taskId: String) async throws -> ListTaskPushNotificationConfigsResponse

    /// Deletes a push notification config.
    func deletePushConfig(taskId: String, configId: String) async throws
}
