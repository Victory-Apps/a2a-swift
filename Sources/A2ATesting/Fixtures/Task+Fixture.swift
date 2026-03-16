import Foundation

extension A2ATask {
    /// Creates a fixture `A2ATask` with sensible defaults for testing.
    public static func fixture(
        id: String = UUID().uuidString,
        contextId: String? = nil,
        status: TaskStatus = .fixture(),
        artifacts: [Artifact]? = nil,
        history: [Message]? = nil
    ) -> A2ATask {
        A2ATask(
            id: id,
            contextId: contextId,
            status: status,
            artifacts: artifacts,
            history: history
        )
    }
}

extension TaskStatus {
    /// Creates a fixture `TaskStatus` with sensible defaults for testing.
    public static func fixture(
        state: TaskState = .submitted,
        message: Message? = nil,
        timestamp: String? = nil
    ) -> TaskStatus {
        TaskStatus(
            state: state,
            message: message,
            timestamp: timestamp
        )
    }
}

extension TaskStatusUpdateEvent {
    /// Creates a fixture `TaskStatusUpdateEvent` with sensible defaults for testing.
    public static func fixture(
        taskId: String = "test-task",
        contextId: String = "test-context",
        status: TaskStatus = .fixture()
    ) -> TaskStatusUpdateEvent {
        TaskStatusUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            status: status
        )
    }
}

extension TaskArtifactUpdateEvent {
    /// Creates a fixture `TaskArtifactUpdateEvent` with sensible defaults for testing.
    public static func fixture(
        taskId: String = "test-task",
        contextId: String = "test-context",
        artifact: Artifact = .fixture(),
        append: Bool? = nil,
        lastChunk: Bool? = nil
    ) -> TaskArtifactUpdateEvent {
        TaskArtifactUpdateEvent(
            taskId: taskId,
            contextId: contextId,
            artifact: artifact,
            append: append,
            lastChunk: lastChunk
        )
    }
}
