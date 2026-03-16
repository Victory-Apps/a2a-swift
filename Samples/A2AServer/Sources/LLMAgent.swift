import A2A
import Foundation

/// An A2A agent backed by Ollama for real LLM-powered responses.
///
/// Streams tokens from Ollama's chat API directly to the A2A client
/// via SSE, demonstrating true agent-to-agent AI communication.
struct LLMAgent: AgentExecutor {
    let ollama: OllamaClient
    let systemPrompt: String

    init(
        ollama: OllamaClient = OllamaClient(fromEnvironment: ()),
        systemPrompt: String = "You are a helpful, concise assistant. Keep responses focused and under 200 words unless asked for more detail."
    ) {
        self.ollama = ollama
        self.systemPrompt = systemPrompt
    }

    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork(message: "Thinking...")

        let artifactId = UUID().uuidString
        var isFirst = true

        let messages = [OllamaMessage.user(context.userText)]
        let stream = ollama.chatStream(messages: messages, system: systemPrompt)

        do {
            for try await chunk in stream {
                updater.streamText(
                    chunk,
                    artifactId: artifactId,
                    name: "response",
                    append: !isFirst,
                    lastChunk: false
                )
                isFirst = false  // After first chunk, always append
            }

            // Signal final chunk
            updater.streamText("", artifactId: artifactId, append: true, lastChunk: true)
            updater.complete()
        } catch {
            if isFirst {
                // No tokens received — Ollama might be down
                updater.fail(message: "Failed to get response from Ollama: \(error.localizedDescription)")
            } else {
                // Partial response received, complete with error note
                updater.streamText(
                    "\n\n[Stream interrupted: \(error.localizedDescription)]",
                    artifactId: artifactId,
                    append: true,
                    lastChunk: true
                )
                updater.complete()
            }
        }
    }
}
