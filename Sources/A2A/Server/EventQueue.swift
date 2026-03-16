import Foundation

/// An event that can flow through an EventQueue.
public enum AgentEvent: Sendable {
    /// A status update for the task.
    case statusUpdate(TaskStatusUpdateEvent)
    /// An artifact update (new or appended chunk).
    case artifactUpdate(TaskArtifactUpdateEvent)
    /// A message from the agent.
    case message(Message)
    /// Signals the end of the event stream.
    case completed
}

/// A bounded, multi-subscriber async event queue.
///
/// Supports creating child subscriptions (via `subscribe()`) that receive all future
/// events independently, enabling multiple SSE subscribers to the same task.
///
/// Uses native Swift `AsyncSequence` for idiomatic consumption:
/// ```swift
/// for await event in queue.subscribe() {
///     switch event { ... }
/// }
/// ```
public final class EventQueue: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<AgentEvent>.Continuation] = [:]
    private var isClosed = false
    private let capacity: Int

    /// Creates a new event queue.
    /// - Parameter capacity: Maximum buffer size per subscriber. Defaults to 100.
    public init(capacity: Int = 100) {
        self.capacity = capacity
    }

    /// Enqueues an event to all current subscribers.
    public func enqueue(_ event: AgentEvent) {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        let continuations = self.continuations
        lock.unlock()

        for (_, continuation) in continuations {
            continuation.yield(event)
        }
    }

    /// Closes the queue. All subscribers receive a `.completed` event and the stream ends.
    public func close() {
        lock.lock()
        guard !isClosed else {
            lock.unlock()
            return
        }
        isClosed = true
        let continuations = self.continuations
        self.continuations.removeAll()
        lock.unlock()

        for (_, continuation) in continuations {
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    /// Whether the queue has been closed.
    public var closed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isClosed
    }

    /// Creates a new `AsyncSequence` subscriber. Each subscriber independently receives
    /// all events enqueued after subscription.
    ///
    /// This is equivalent to "tapping" the event stream -- each call creates an independent
    /// consumer that won't interfere with other subscribers.
    ///
    /// Usage:
    /// ```swift
    /// for await event in queue.subscribe() {
    ///     switch event {
    ///     case .statusUpdate(let update): handleStatus(update)
    ///     case .artifactUpdate(let update): handleArtifact(update)
    ///     case .message(let msg): handleMessage(msg)
    ///     case .completed: break
    ///     }
    /// }
    /// ```
    public func subscribe() -> EventSubscription {
        let id = UUID()

        let stream = AsyncStream<AgentEvent>(bufferingPolicy: .bufferingNewest(capacity)) { continuation in
            lock.lock()
            if isClosed {
                lock.unlock()
                continuation.yield(.completed)
                continuation.finish()
                return
            }
            continuations[id] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.removeSubscriber(id)
            }
        }
        return EventSubscription(stream: stream)
    }

    /// Convenience: creates a subscriber `AsyncSequence` that maps events to `StreamResponse`.
    public func streamResponses(taskId: String, contextId: String) -> StreamResponseSequence {
        StreamResponseSequence(subscription: subscribe())
    }

    private func removeSubscriber(_ id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }
}

// MARK: - AsyncSequence Types

/// An `AsyncSequence` of `AgentEvent` values from an `EventQueue` subscription.
public struct EventSubscription: AsyncSequence, Sendable {
    public typealias Element = AgentEvent

    let stream: AsyncStream<AgentEvent>

    public func makeAsyncIterator() -> AsyncStream<AgentEvent>.AsyncIterator {
        stream.makeAsyncIterator()
    }
}

/// An `AsyncSequence` of `StreamResponse` values mapped from an `EventSubscription`.
public struct StreamResponseSequence: AsyncSequence, Sendable {
    public typealias Element = StreamResponse

    private let subscription: EventSubscription

    init(subscription: EventSubscription) {
        self.subscription = subscription
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        var base: AsyncStream<AgentEvent>.AsyncIterator

        public mutating func next() async -> StreamResponse? {
            while let event = await base.next() {
                switch event {
                case .statusUpdate(let update):
                    return .statusUpdate(update)
                case .artifactUpdate(let update):
                    return .artifactUpdate(update)
                case .message(let message):
                    return .message(message)
                case .completed:
                    return nil
                }
            }
            return nil
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: subscription.stream.makeAsyncIterator())
    }
}

// MARK: - EventQueueManager

/// Manages event queues for multiple tasks.
public actor EventQueueManager {
    private var queues: [String: EventQueue] = [:]

    public init() {}

    /// Gets or creates an event queue for a task.
    /// If the existing queue was closed (task completed), creates a fresh one.
    public func queue(for taskId: String, capacity: Int = 100) -> EventQueue {
        if let existing = queues[taskId], !existing.closed {
            return existing
        }
        let queue = EventQueue(capacity: capacity)
        queues[taskId] = queue
        return queue
    }

    /// Gets an existing queue for a task, if any.
    public func existingQueue(for taskId: String) -> EventQueue? {
        queues[taskId]
    }

    /// Removes a queue for a task (e.g., after task completion).
    public func removeQueue(for taskId: String) {
        if let queue = queues.removeValue(forKey: taskId) {
            queue.close()
        }
    }

    /// Closes and removes all queues.
    public func removeAll() {
        for (_, queue) in queues {
            queue.close()
        }
        queues.removeAll()
    }
}
