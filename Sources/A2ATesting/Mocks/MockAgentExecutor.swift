import Foundation

/// A configurable ``AgentExecutor`` for testing.
///
/// Use the closure-based initializer for custom behavior, or one of the
/// static factory methods for common patterns:
///
/// ```swift
/// // Custom behavior
/// let executor = MockAgentExecutor { context, updater in
///     updater.startWork()
///     updater.addArtifact(parts: [.text("custom")])
///     updater.complete()
/// }
///
/// // Presets
/// let echo = MockAgentExecutor.echo()
/// let fail = MockAgentExecutor.failing()
/// let done = MockAgentExecutor.completing(with: "Result")
/// ```
public struct MockAgentExecutor: AgentExecutor {
    private let _execute: @Sendable (RequestContext, TaskUpdater) async throws -> Void
    private let _cancel: (@Sendable (RequestContext, TaskUpdater) async throws -> Void)?

    public init(
        onExecute: @escaping @Sendable (RequestContext, TaskUpdater) async throws -> Void = { _, updater in
            updater.complete()
        },
        onCancel: (@Sendable (RequestContext, TaskUpdater) async throws -> Void)? = nil
    ) {
        self._execute = onExecute
        self._cancel = onCancel
    }

    public func execute(context: RequestContext, updater: TaskUpdater) async throws {
        try await _execute(context, updater)
    }

    public func cancel(context: RequestContext, updater: TaskUpdater) async throws {
        if let _cancel {
            try await _cancel(context, updater)
        } else {
            updater.updateStatus(.canceled)
        }
    }
}

// MARK: - Presets

extension MockAgentExecutor {
    /// An executor that echoes the user's message parts back as an artifact.
    public static func echo() -> MockAgentExecutor {
        MockAgentExecutor { context, updater in
            updater.startWork(message: "Processing...")
            updater.addArtifact(parts: context.userMessage.parts)
            updater.complete(message: "Done")
        }
    }

    /// An executor that immediately throws an error.
    public static func failing(
        error: Error = A2AError.internalError("Something went wrong")
    ) -> MockAgentExecutor {
        MockAgentExecutor { _, _ in throw error }
    }

    /// An executor that completes with the given text as an artifact.
    public static func completing(with text: String) -> MockAgentExecutor {
        MockAgentExecutor { _, updater in
            updater.startWork()
            updater.addArtifact(parts: [.text(text)])
            updater.complete()
        }
    }

    /// An executor that requests additional input from the user.
    public static func inputRequired(message: String) -> MockAgentExecutor {
        MockAgentExecutor { _, updater in
            updater.startWork()
            updater.requireInput(message: message)
        }
    }
}
