import A2A
import Foundation

/// A streaming echo agent that repeats user input word-by-word.
///
/// Demonstrates:
/// - `AgentExecutor` protocol implementation
/// - Streaming text output via `TaskUpdater.streamText()`
/// - Task lifecycle (startWork → stream → complete)
struct EchoAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork(message: "Processing your message...")

        let words = context.userText.split(separator: " ")
        let artifactId = UUID().uuidString

        for (index, word) in words.enumerated() {
            // Simulate processing delay for streaming effect
            try await Task.sleep(for: .milliseconds(100))

            updater.streamText(
                index > 0 ? " \(word)" : String(word),
                artifactId: artifactId,
                name: "echo-response",
                append: index > 0,
                lastChunk: index == words.count - 1
            )
        }

        updater.complete(message: "Echoed your message!")
    }
}
