/// Error thrown by stream assertion helpers when an event doesn't match the expected type.
public struct StreamAssertionError: Error, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

extension Array where Element == StreamResponse {
    /// All task snapshots in the stream.
    public var tasks: [A2ATask] {
        compactMap { if case .task(let t) = $0 { return t } else { return nil } }
    }

    /// All status update events in the stream.
    public var statusUpdates: [TaskStatusUpdateEvent] {
        compactMap { if case .statusUpdate(let u) = $0 { return u } else { return nil } }
    }

    /// All artifact update events in the stream.
    public var artifactUpdates: [TaskArtifactUpdateEvent] {
        compactMap { if case .artifactUpdate(let a) = $0 { return a } else { return nil } }
    }

    /// All message events in the stream.
    public var messages: [Message] {
        compactMap { if case .message(let m) = $0 { return m } else { return nil } }
    }

    /// Returns the task at the given index, or throws if the element is not a `.task`.
    public func task(at index: Int) throws -> A2ATask {
        guard index < count else {
            throw StreamAssertionError("Index \(index) out of bounds (count: \(count))")
        }
        guard case .task(let task) = self[index] else {
            throw StreamAssertionError("Expected .task at index \(index), got \(self[index])")
        }
        return task
    }

    /// Returns the status update at the given index, or throws if the element is not a `.statusUpdate`.
    public func statusUpdate(at index: Int) throws -> TaskStatusUpdateEvent {
        guard index < count else {
            throw StreamAssertionError("Index \(index) out of bounds (count: \(count))")
        }
        guard case .statusUpdate(let update) = self[index] else {
            throw StreamAssertionError("Expected .statusUpdate at index \(index), got \(self[index])")
        }
        return update
    }

    /// Returns the artifact update at the given index, or throws if the element is not a `.artifactUpdate`.
    public func artifactUpdate(at index: Int) throws -> TaskArtifactUpdateEvent {
        guard index < count else {
            throw StreamAssertionError("Index \(index) out of bounds (count: \(count))")
        }
        guard case .artifactUpdate(let update) = self[index] else {
            throw StreamAssertionError("Expected .artifactUpdate at index \(index), got \(self[index])")
        }
        return update
    }

    /// Returns the message at the given index, or throws if the element is not a `.message`.
    public func message(at index: Int) throws -> Message {
        guard index < count else {
            throw StreamAssertionError("Index \(index) out of bounds (count: \(count))")
        }
        guard case .message(let msg) = self[index] else {
            throw StreamAssertionError("Expected .message at index \(index), got \(self[index])")
        }
        return msg
    }

    /// Whether any status update in the stream has the given state.
    public func containsStatus(_ state: TaskState) -> Bool {
        statusUpdates.contains { $0.status.state == state }
    }
}
