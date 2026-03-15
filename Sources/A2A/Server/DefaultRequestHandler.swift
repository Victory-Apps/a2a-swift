import Foundation

/// A complete request handler that orchestrates agent execution, task lifecycle,
/// event processing, and SSE streaming.
///
/// This is the highest-level server component. It implements `A2AAgentHandler` by
/// delegating business logic to an `AgentExecutor` and managing all protocol concerns
/// (task creation, event processing, store updates, push notifications) automatically.
///
/// Usage:
/// ```swift
/// struct MyAgent: AgentExecutor {
///     func execute(context: RequestContext, updater: TaskUpdater) async throws {
///         updater.startWork()
///         updater.addArtifact(parts: [.text("Result")])
///         updater.complete()
///     }
/// }
///
/// let handler = DefaultRequestHandler(
///     executor: MyAgent(),
///     card: myAgentCard,
///     store: InMemoryTaskStore()
/// )
/// let router = A2ARouter(handler: handler)
/// ```
public final class DefaultRequestHandler: A2AAgentHandler, Sendable {
    private let executor: any AgentExecutor
    private let card: AgentCard
    private let extendedCard: AgentCard?
    private let taskManager: TaskManager
    private let queueManager: EventQueueManager

    public init(
        executor: any AgentExecutor,
        card: AgentCard,
        extendedCard: AgentCard? = nil,
        store: any TaskStore = InMemoryTaskStore(),
        pushSender: PushNotificationSender? = nil
    ) {
        let queueManager = EventQueueManager()
        self.executor = executor
        self.card = card
        self.extendedCard = extendedCard
        self.queueManager = queueManager
        self.taskManager = TaskManager(
            store: store,
            queueManager: queueManager,
            pushSender: pushSender
        )
    }

    public func agentCard() async throws -> AgentCard {
        card
    }

    public func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        let (task, queue, isNew) = try await taskManager.getOrCreateTask(for: request)
        let contextId = task.contextId ?? task.id
        let updater = TaskUpdater(queue: queue, taskId: task.id, contextId: contextId)
        let context = RequestContext(
            task: task,
            userMessage: request.message,
            request: request,
            isNewTask: isNew
        )

        // Start processing events in background
        let processingTask = await taskManager.processEvents(
            taskId: task.id,
            contextId: contextId,
            queue: queue
        )

        // Execute the agent
        do {
            try await executor.execute(context: context, updater: updater)
        } catch {
            updater.fail(message: error.localizedDescription)
        }

        // If the queue is still open (agent didn't call complete/fail), close it
        if !queue.closed {
            updater.complete()
        }

        // Wait for event processing to complete and return the final task
        let finalTask = try await processingTask.value
        return .task(finalTask)
    }

    public func handleSendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let (task, queue, isNew) = try await taskManager.getOrCreateTask(for: request)
        let contextId = task.contextId ?? task.id
        let updater = TaskUpdater(queue: queue, taskId: task.id, contextId: contextId)
        let context = RequestContext(
            task: task,
            userMessage: request.message,
            request: request,
            isNewTask: isNew
        )

        // Start processing events in background (updates store)
        _ = await taskManager.processEvents(
            taskId: task.id,
            contextId: contextId,
            queue: queue
        )

        // Subscribe to the event stream for SSE delivery
        let responseStream = queue.streamResponses(taskId: task.id, contextId: contextId)

        // Execute the agent in background
        Task { [executor] in
            do {
                try await executor.execute(context: context, updater: updater)
            } catch {
                updater.fail(message: error.localizedDescription)
            }
            if !queue.closed {
                updater.complete()
            }
        }

        // Convert to AsyncThrowingStream
        return AsyncThrowingStream { continuation in
            let streamTask = Task {
                // First emit the initial task
                continuation.yield(.task(task))

                for await response in responseStream {
                    guard !Task.isCancelled else { break }
                    continuation.yield(response)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    public func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await taskManager.getTask(id: request.id, historyLength: request.historyLength)
    }

    public func handleListTasks(_ request: ListTasksRequest) async throws -> ListTasksResponse {
        try await taskManager.listTasks(request)
    }

    public func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        let task = try await taskManager.getTask(id: request.id)
        let contextId = task.contextId ?? task.id

        guard !task.status.state.isTerminal else {
            throw A2AError.taskNotCancelable(taskId: request.id)
        }

        // Get or create queue for cancel events
        let queue = await queueManager.queue(for: task.id)
        let updater = TaskUpdater(queue: queue, taskId: task.id, contextId: contextId)
        let context = RequestContext(
            task: task,
            userMessage: Message(role: .user, parts: []),
            request: SendMessageRequest(message: Message(role: .user, parts: [])),
            isNewTask: false
        )

        try await executor.cancel(context: context, updater: updater)

        return try await taskManager.cancelTask(id: request.id)
    }

    public func handleSubscribeToTask(_ request: SubscribeToTaskRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        let queue = try await taskManager.subscribeToTask(id: request.id)
        let task = try await taskManager.getTask(id: request.id)
        let contextId = task.contextId ?? task.id
        let responseStream = queue.streamResponses(taskId: request.id, contextId: contextId)

        return AsyncThrowingStream { continuation in
            let streamTask = Task {
                // Emit current task state first
                continuation.yield(.task(task))

                for await response in responseStream {
                    guard !Task.isCancelled else { break }
                    continuation.yield(response)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                streamTask.cancel()
            }
        }
    }

    public func handleCreateTaskPushNotificationConfig(_ config: TaskPushNotificationConfig) async throws -> TaskPushNotificationConfig {
        guard card.capabilities.pushNotifications == true else {
            throw A2AError(code: .pushNotificationNotSupported)
        }
        return try await taskManager.createPushConfig(config)
    }

    public func handleGetTaskPushNotificationConfig(_ request: GetTaskPushNotificationConfigRequest) async throws -> TaskPushNotificationConfig {
        try await taskManager.getPushConfig(taskId: request.taskId, configId: request.id)
    }

    public func handleListTaskPushNotificationConfigs(_ request: ListTaskPushNotificationConfigsRequest) async throws -> ListTaskPushNotificationConfigsResponse {
        try await taskManager.listPushConfigs(taskId: request.taskId)
    }

    public func handleDeleteTaskPushNotificationConfig(_ request: DeleteTaskPushNotificationConfigRequest) async throws {
        try await taskManager.deletePushConfig(taskId: request.taskId, configId: request.id)
    }

    public func handleGetExtendedAgentCard(_ request: GetExtendedAgentCardRequest) async throws -> AgentCard {
        guard let extended = extendedCard else {
            throw A2AError(code: .extendedAgentCardNotConfigured)
        }
        return extended
    }
}
