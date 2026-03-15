import Foundation

/// Context for a request being processed by an agent executor.
/// Carries all relevant information about the incoming request and the task being processed.
public struct RequestContext: Sendable {
    /// The task being worked on.
    public let task: A2ATask

    /// The user's message that initiated this request.
    public let userMessage: Message

    /// The full request that was sent.
    public let request: SendMessageRequest

    /// Whether this is a new task or a continuation of an existing one.
    public let isNewTask: Bool

    public init(
        task: A2ATask,
        userMessage: Message,
        request: SendMessageRequest,
        isNewTask: Bool
    ) {
        self.task = task
        self.userMessage = userMessage
        self.request = request
        self.isNewTask = isNewTask
    }

    /// Extracts all text content from the user's message.
    public var userText: String {
        userMessage.parts.compactMap(\.text).joined(separator: "\n")
    }

    /// The task ID.
    public var taskId: String { task.id }

    /// The context ID.
    public var contextId: String? { task.contextId }
}

/// Convenience helpers for agents to emit events.
public struct TaskUpdater: Sendable {
    private let queue: EventQueue
    public let taskId: String
    public let contextId: String

    public init(queue: EventQueue, taskId: String, contextId: String) {
        self.queue = queue
        self.taskId = taskId
        self.contextId = contextId
    }

    /// Emits a status update indicating the agent is working.
    public func startWork(message: String? = nil) {
        let status = TaskStatus(
            state: .working,
            message: message.map { Message(role: .agent, parts: [.text($0)]) },
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )))
    }

    /// Emits a status update indicating the task is complete.
    public func complete(message: String? = nil) {
        let status = TaskStatus(
            state: .completed,
            message: message.map { Message(role: .agent, parts: [.text($0)]) },
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )))
        queue.close()
    }

    /// Emits a status update indicating the task failed.
    public func fail(message: String? = nil) {
        let status = TaskStatus(
            state: .failed,
            message: message.map { Message(role: .agent, parts: [.text($0)]) },
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )))
        queue.close()
    }

    /// Emits a status update indicating user input is required.
    public func requireInput(message: String) {
        let status = TaskStatus(
            state: .inputRequired,
            message: Message(role: .agent, parts: [.text(message)]),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )))
    }

    /// Emits a status update indicating authentication is required.
    public func requireAuth(message: String? = nil) {
        let status = TaskStatus(
            state: .authRequired,
            message: message.map { Message(role: .agent, parts: [.text($0)]) },
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )))
    }

    /// Emits an artifact with the given content.
    public func addArtifact(
        artifactId: String = UUID().uuidString,
        name: String? = nil,
        description: String? = nil,
        parts: [Part],
        append: Bool = false,
        lastChunk: Bool = true
    ) {
        queue.enqueue(.artifactUpdate(TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: Artifact(artifactId: artifactId, name: name, description: description, parts: parts),
            append: append,
            lastChunk: lastChunk
        )))
    }

    /// Emits a text artifact chunk (for streaming text output).
    public func streamText(
        _ text: String,
        artifactId: String,
        name: String? = nil,
        append: Bool = true,
        lastChunk: Bool = false
    ) {
        addArtifact(
            artifactId: artifactId,
            name: name,
            parts: [.text(text)],
            append: append,
            lastChunk: lastChunk
        )
    }

    /// Emits a message from the agent.
    public func sendMessage(parts: [Part], metadata: [String: JSONValue]? = nil) {
        queue.enqueue(.message(Message(
            role: .agent,
            parts: parts,
            metadata: metadata
        )))
    }

    /// Emits a custom status update.
    public func updateStatus(_ state: TaskState, message: Message? = nil, metadata: [String: JSONValue]? = nil) {
        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: TaskStatus(
                state: state,
                message: message,
                timestamp: ISO8601DateFormatter().string(from: Date())
            ),
            metadata: metadata
        )))
        if state.isTerminal {
            queue.close()
        }
    }
}
