import Foundation

/// A thread-safe in-memory implementation of ``TaskStore``.
///
/// Suitable for development, testing, and single-instance deployments.
/// Data is lost when the process exits. For production use with persistence,
/// implement ``TaskStore`` with your preferred database.
///
/// This is the default store used by ``DefaultRequestHandler`` when no custom
/// store is provided.
public actor InMemoryTaskStore: TaskStore {
    private var tasks: [String: A2ATask] = [:]
    private var pushConfigs: [String: [String: TaskPushNotificationConfig]] = [:] // taskId -> configId -> config

    public init() {}

    // MARK: - Task Operations

    public func createTask(contextId: String?, status: TaskStatus, metadata: [String: JSONValue]?) async throws -> A2ATask {
        let task = A2ATask(
            id: UUID().uuidString,
            contextId: contextId,
            status: status,
            metadata: metadata
        )
        tasks[task.id] = task
        return task
    }

    public func getTask(id: String, historyLength: Int?) async throws -> A2ATask {
        guard var task = tasks[id] else {
            throw A2AError.taskNotFound(taskId: id)
        }

        if let limit = historyLength, let history = task.history {
            task.history = Array(history.suffix(limit))
        }

        return task
    }

    public func updateTaskStatus(id: String, status: TaskStatus) async throws -> A2ATask {
        guard var task = tasks[id] else {
            throw A2AError.taskNotFound(taskId: id)
        }
        task.status = status
        tasks[id] = task
        return task
    }

    public func addMessage(taskId: String, message: Message) async throws -> A2ATask {
        guard var task = tasks[taskId] else {
            throw A2AError.taskNotFound(taskId: taskId)
        }
        if task.history == nil {
            task.history = []
        }
        task.history?.append(message)
        tasks[taskId] = task
        return task
    }

    public func addArtifact(taskId: String, artifact: Artifact) async throws -> A2ATask {
        guard var task = tasks[taskId] else {
            throw A2AError.taskNotFound(taskId: taskId)
        }
        if task.artifacts == nil {
            task.artifacts = []
        }
        task.artifacts?.append(artifact)
        tasks[taskId] = task
        return task
    }

    public func appendToArtifact(taskId: String, artifactId: String, parts: [Part]) async throws -> A2ATask {
        guard var task = tasks[taskId] else {
            throw A2AError.taskNotFound(taskId: taskId)
        }
        guard let index = task.artifacts?.firstIndex(where: { $0.artifactId == artifactId }) else {
            let artifact = Artifact(artifactId: artifactId, parts: parts)
            if task.artifacts == nil {
                task.artifacts = [artifact]
            } else {
                task.artifacts?.append(artifact)
            }
            tasks[taskId] = task
            return task
        }
        task.artifacts?[index].parts.append(contentsOf: parts)
        tasks[taskId] = task
        return task
    }

    public func listTasks(
        contextId: String?,
        state: TaskState?,
        pageSize: Int,
        pageToken: String?,
        historyLength: Int?,
        includeArtifacts: Bool
    ) async throws -> ListTasksResponse {
        var filtered = Array(tasks.values)

        if let contextId = contextId {
            filtered = filtered.filter { $0.contextId == contextId }
        }
        if let state = state {
            filtered = filtered.filter { $0.status.state == state }
        }

        let total = filtered.count
        let startIndex: Int
        if let token = pageToken, let index = Int(token) {
            startIndex = index
        } else {
            startIndex = 0
        }

        let endIndex = min(startIndex + pageSize, filtered.count)
        var page = Array(filtered[startIndex..<endIndex])

        if let limit = historyLength {
            page = page.map { task in
                var t = task
                if let history = t.history {
                    t.history = Array(history.suffix(limit))
                }
                return t
            }
        }

        if !includeArtifacts {
            page = page.map { task in
                var t = task
                t.artifacts = nil
                return t
            }
        }

        let nextToken = endIndex < filtered.count ? String(endIndex) : ""

        return ListTasksResponse(
            tasks: page,
            nextPageToken: nextToken,
            pageSize: pageSize,
            totalSize: total
        )
    }

    public func cancelTask(id: String) async throws -> A2ATask {
        guard var task = tasks[id] else {
            throw A2AError.taskNotFound(taskId: id)
        }

        guard !task.status.state.isTerminal else {
            throw A2AError.taskNotCancelable(taskId: id)
        }

        task.status = TaskStatus(state: .canceled)
        tasks[id] = task
        return task
    }

    // MARK: - Push Notification Config Operations

    public func createPushConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        guard let taskId = config.taskId else {
            throw A2AError(code: .invalidParams, message: "taskId is required")
        }
        guard tasks[taskId] != nil else {
            throw A2AError.taskNotFound(taskId: taskId)
        }

        var updatedConfig = config
        if updatedConfig.id == nil {
            updatedConfig.id = UUID().uuidString
        }

        if pushConfigs[taskId] == nil {
            pushConfigs[taskId] = [:]
        }
        pushConfigs[taskId]![updatedConfig.id!] = updatedConfig
        return updatedConfig
    }

    public func getPushConfig(taskId: String, configId: String) async throws -> TaskPushNotificationConfig {
        guard let config = pushConfigs[taskId]?[configId] else {
            throw A2AError.taskNotFound(taskId: taskId)
        }
        return config
    }

    public func listPushConfigs(taskId: String) async throws -> ListTaskPushNotificationConfigsResponse {
        let configs = pushConfigs[taskId]?.values.map { $0 } ?? []
        return ListTaskPushNotificationConfigsResponse(configs: configs)
    }

    public func deletePushConfig(taskId: String, configId: String) async throws {
        guard pushConfigs[taskId]?[configId] != nil else {
            throw A2AError.taskNotFound(taskId: taskId)
        }
        pushConfigs[taskId]?.removeValue(forKey: configId)
    }
}
