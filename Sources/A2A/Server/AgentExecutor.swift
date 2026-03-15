import Foundation

/// Protocol for implementing A2A agent business logic.
///
/// This is the primary interface for building agents. Implement `execute(context:updater:)`
/// to handle incoming messages, using the `TaskUpdater` to emit events.
///
/// The SDK handles all request routing, task lifecycle, SSE streaming, and event
/// processing automatically.
///
/// Example:
/// ```swift
/// struct EchoAgent: AgentExecutor {
///     func execute(context: RequestContext, updater: TaskUpdater) async throws {
///         updater.startWork()
///         updater.addArtifact(parts: context.userMessage.parts)
///         updater.complete(message: "Done")
///     }
///
///     func cancel(context: RequestContext, updater: TaskUpdater) async throws {
///         updater.updateStatus(.canceled, message: Message(role: .agent, parts: [.text("Canceled")]))
///     }
/// }
/// ```
public protocol AgentExecutor: Sendable {
    /// Executes agent logic for the given request.
    ///
    /// Use the `updater` to emit status updates, artifacts, and messages.
    /// The SDK will automatically process these events, update the task store,
    /// and deliver them to SSE subscribers and push notification webhooks.
    ///
    /// - Parameters:
    ///   - context: The request context containing the task and user message.
    ///   - updater: Helper for emitting events (status updates, artifacts, messages).
    func execute(context: RequestContext, updater: TaskUpdater) async throws

    /// Handles cancellation of a task.
    ///
    /// Called when a `CancelTask` request is received for a task that is not in a terminal state.
    /// The default implementation emits a canceled status.
    ///
    /// - Parameters:
    ///   - context: The request context.
    ///   - updater: Helper for emitting events.
    func cancel(context: RequestContext, updater: TaskUpdater) async throws
}

extension AgentExecutor {
    public func cancel(context: RequestContext, updater: TaskUpdater) async throws {
        updater.updateStatus(.canceled)
    }
}
