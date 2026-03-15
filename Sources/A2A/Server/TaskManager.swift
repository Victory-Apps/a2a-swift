import Foundation

/// Processes agent events and updates the task store accordingly.
///
/// TaskManager is the orchestration layer between the agent executor, event queue,
/// and task store. It consumes events from the queue and applies them to the store,
/// keeping the persisted task state in sync with the agent's output.
public actor TaskManager {
    private let store: any TaskStore
    private let queueManager: EventQueueManager
    private let pushSender: PushNotificationSender?

    public init(
        store: any TaskStore,
        queueManager: EventQueueManager,
        pushSender: PushNotificationSender? = nil
    ) {
        self.store = store
        self.queueManager = queueManager
        self.pushSender = pushSender
    }

    /// Creates a new task and returns its ID and event queue.
    public func createTask(
        contextId: String?,
        userMessage: Message,
        metadata: [String: JSONValue]? = nil
    ) async throws -> (task: A2ATask, queue: EventQueue) {
        let task = try await store.createTask(
            contextId: contextId,
            status: TaskStatus(state: .submitted, timestamp: ISO8601DateFormatter().string(from: Date())),
            metadata: metadata
        )

        // Store the user message in history
        _ = try await store.addMessage(taskId: task.id, message: userMessage)

        let queue = await queueManager.queue(for: task.id)
        return (task, queue)
    }

    /// Gets or creates a task for a message (handles existing task references).
    public func getOrCreateTask(
        for request: SendMessageRequest
    ) async throws -> (task: A2ATask, queue: EventQueue, isNew: Bool) {
        let message = request.message

        // If the message references an existing task, use it
        if let taskId = message.taskId {
            let task = try await store.getTask(id: taskId, historyLength: nil)
            _ = try await store.addMessage(taskId: taskId, message: message)
            let queue = await queueManager.queue(for: taskId)
            return (task, queue, false)
        }

        // Create a new task
        let (task, queue) = try await createTask(
            contextId: message.contextId,
            userMessage: message,
            metadata: request.metadata
        )
        return (task, queue, true)
    }

    /// Starts processing events from a queue and updating the store.
    /// Runs in the background until the queue is closed.
    ///
    /// Creates the subscription eagerly so no events are missed, even if the
    /// processing Task starts after events have been enqueued.
    public func processEvents(
        taskId: String,
        contextId: String,
        queue: EventQueue
    ) -> Task<A2ATask, Error> {
        let store = self.store
        let pushSender = self.pushSender
        // Subscribe eagerly before the Task starts, so we don't miss events
        let subscription = queue.subscribe()

        return Task {
            var latestTask: A2ATask? = nil

            for await event in subscription {
                switch event {
                case .statusUpdate(let update):
                    latestTask = try await store.updateTaskStatus(id: taskId, status: update.status)

                    // Send push notifications if configured
                    if let sender = pushSender {
                        let configs = try await store.listPushConfigs(taskId: taskId)
                        for config in configs.configs {
                            await sender.send(
                                StreamResponse.statusUpdate(update),
                                to: config
                            )
                        }
                    }

                case .artifactUpdate(let update):
                    if update.append == true {
                        latestTask = try await store.appendToArtifact(
                            taskId: taskId,
                            artifactId: update.artifact.artifactId,
                            parts: update.artifact.parts
                        )
                    } else {
                        latestTask = try await store.addArtifact(taskId: taskId, artifact: update.artifact)
                    }

                    // Send push notifications if configured
                    if let sender = pushSender {
                        let configs = try await store.listPushConfigs(taskId: taskId)
                        for config in configs.configs {
                            await sender.send(
                                StreamResponse.artifactUpdate(update),
                                to: config
                            )
                        }
                    }

                case .message(let message):
                    latestTask = try await store.addMessage(taskId: taskId, message: message)

                case .completed:
                    break
                }
            }

            if let latestTask = latestTask {
                return latestTask
            }
            return try await store.getTask(id: taskId, historyLength: nil)
        }
    }

    /// Cancels a task, notifying the agent executor.
    public func cancelTask(id: String) async throws -> A2ATask {
        try await store.cancelTask(id: id)
    }

    /// Gets a task from the store.
    public func getTask(id: String, historyLength: Int? = nil) async throws -> A2ATask {
        try await store.getTask(id: id, historyLength: historyLength)
    }

    /// Lists tasks from the store.
    public func listTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        try await store.listTasks(
            contextId: request.contextId,
            state: request.status,
            pageSize: request.pageSize ?? 50,
            pageToken: request.pageToken,
            historyLength: request.historyLength,
            includeArtifacts: request.includeArtifacts ?? false
        )
    }

    /// Gets the event queue for task subscription (SSE).
    public func subscribeToTask(id: String) async throws -> EventQueue {
        // Verify the task exists
        _ = try await store.getTask(id: id, historyLength: nil)
        return await queueManager.queue(for: id)
    }

    // MARK: - Push Notification Config delegation

    public func createPushConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        try await store.createPushConfig(config)
    }

    public func getPushConfig(taskId: String, configId: String) async throws -> TaskPushNotificationConfig {
        try await store.getPushConfig(taskId: taskId, configId: configId)
    }

    public func listPushConfigs(taskId: String) async throws -> ListTaskPushNotificationConfigsResponse {
        try await store.listPushConfigs(taskId: taskId)
    }

    public func deletePushConfig(taskId: String, configId: String) async throws {
        try await store.deletePushConfig(taskId: taskId, configId: configId)
    }
}
