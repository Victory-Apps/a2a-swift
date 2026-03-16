import A2A
import Foundation

/// Manages connections to remote A2A agents.
@MainActor
final class A2AService {
    private var clients: [URL: A2AClient] = [:]
    /// Tracks the active task ID per agent URL for conversation continuity.
    private var activeTaskIds: [URL: String] = [:]

    /// URLSession with extended timeout for streaming LLM responses.
    private let streamingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for slow LLM responses
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    /// Discovers and connects to an agent at the given URL.
    func connect(to url: URL) async throws -> AgentCard {
        let client = A2AClient(baseURL: url, session: streamingSession)
        let card = try await client.fetchAgentCard()
        clients[url] = client
        return card
    }

    /// Disconnects from an agent.
    func disconnect(from url: URL) {
        clients.removeValue(forKey: url)
        activeTaskIds.removeValue(forKey: url)
    }

    /// Clears conversation history for all agents (starts fresh tasks).
    func clearConversationHistory() {
        activeTaskIds.removeAll()
    }

    /// Sends a message to an agent, choosing streaming or non-streaming based on capabilities.
    /// Automatically reuses the active task ID for conversation continuity.
    func sendMessage(
        _ text: String,
        to url: URL,
        streaming: Bool
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let taskId = activeTaskIds[url]
        print("┌─── 📡 A2A CLIENT REQUEST ─────────────────────")
        print("│ To: \(url)")
        print("│ Mode: \(streaming ? "Streaming (SendStreamingMessage)" : "Non-streaming (SendMessage)")")
        print("│ Message: \"\(text.prefix(100))\"")
        print("│ TaskId: \(taskId ?? "(new)")")
        print("└───────────────────────────────────────────────")
        if streaming {
            return sendStreamingMessage(text, to: url, taskId: taskId)
        } else {
            return sendNonStreamingMessage(text, to: url, taskId: taskId)
        }
    }

    /// Sends a streaming message to an agent and yields text chunks.
    private func sendStreamingMessage(
        _ text: String,
        to url: URL,
        taskId: String? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let client = self?.clients[url] else {
                    continuation.finish(throwing: A2AServiceError.notConnected)
                    return
                }

                do {
                    var request = SendMessageRequest(
                        message: Message(role: .user, parts: [.text(text)])
                    )
                    if let taskId {
                        request.message.taskId = taskId
                    }

                    let stream = try await client.sendStreamingMessage(request)

                    var chunkCount = 0
                    var totalText = ""
                    for try await event in stream {
                        guard !Task.isCancelled else { break }

                        switch event {
                        case .task(let a2aTask):
                            print("  📥 SSE: Task created (id: \(a2aTask.id))")
                            // Store task ID for conversation continuity
                            await MainActor.run { self?.activeTaskIds[url] = a2aTask.id }
                            continuation.yield(.taskCreated(id: a2aTask.id))

                        case .statusUpdate(let update):
                            if let statusMsg = update.status.message?.parts.compactMap(\.text).joined(),
                               !statusMsg.isEmpty {
                                print("  📥 SSE: Status → \"\(statusMsg)\"")
                                continuation.yield(.status(statusMsg))
                            }
                            // Terminal states mean no more events are coming.
                            // Finish the stream rather than waiting for the HTTP
                            // connection to close (which may hang with keep-alive).
                            if update.status.state.isTerminal {
                                print("  📥 SSE: Terminal state reached (\(update.status.state))")
                                continuation.finish()
                                return
                            }

                        case .artifactUpdate(let update):
                            let newText = update.artifact.parts.compactMap(\.text).joined()
                            if !newText.isEmpty {
                                chunkCount += 1
                                totalText += newText
                                if chunkCount <= 3 {
                                    print("  📥 SSE: Artifact chunk #\(chunkCount) → \"\(newText.prefix(50))\"")
                                }
                                continuation.yield(.text(newText, append: update.append ?? false))
                            }

                        case .message(let message):
                            let msgText = message.parts.compactMap(\.text).joined()
                            if !msgText.isEmpty {
                                // Skip agent messages that duplicate already-streamed artifact content
                                // (these are sent by the server for history storage only)
                                if chunkCount > 0 && message.role == .agent {
                                    print("  📥 SSE: Message (history-only, skipping display) → \"\(msgText.prefix(80))\"")
                                } else {
                                    print("  📥 SSE: Message → \"\(msgText.prefix(80))\"")
                                    continuation.yield(.text(msgText, append: true))
                                }
                            }
                        }
                    }
                    print("┌─── 📥 A2A STREAMING COMPLETE ─────────────────")
                    print("│ Chunks received: \(chunkCount)")
                    print("│ Total response: \"\(totalText.prefix(200))\"")
                    print("└───────────────────────────────────────────────")
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Sends a non-streaming message and returns the complete response as a single event.
    private func sendNonStreamingMessage(
        _ text: String,
        to url: URL,
        taskId: String? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [weak self] in
                guard let client = self?.clients[url] else {
                    continuation.finish(throwing: A2AServiceError.notConnected)
                    return
                }

                do {
                    var request = SendMessageRequest(
                        message: Message(role: .user, parts: [.text(text)])
                    )
                    if let taskId {
                        request.message.taskId = taskId
                    }

                    let response = try await client.sendMessage(request)

                    // Extract text from the response
                    switch response {
                    case .task(let a2aTask):
                        print("  📥 Response: Task (id: \(a2aTask.id), state: \(a2aTask.status.state))")
                        // Store task ID for conversation continuity
                        await MainActor.run { self?.activeTaskIds[url] = a2aTask.id }
                        continuation.yield(.taskCreated(id: a2aTask.id))

                        // Yield artifact text
                        for artifact in a2aTask.artifacts ?? [] {
                            let artifactText = artifact.parts.compactMap(\.text).joined()
                            if !artifactText.isEmpty {
                                print("┌─── 📥 A2A NON-STREAMING RESPONSE ────────────")
                                print("│ Artifact: \"\(artifactText.prefix(200))\"")
                                print("└───────────────────────────────────────────────")
                                continuation.yield(.text(artifactText, append: false))
                            }
                        }

                        // Yield agent messages from history
                        for message in a2aTask.history ?? [] where message.role == .agent {
                            let msgText = message.parts.compactMap(\.text).joined()
                            if !msgText.isEmpty {
                                continuation.yield(.text(msgText, append: false))
                            }
                        }

                    case .message(let message):
                        let msgText = message.parts.compactMap(\.text).joined()
                        if !msgText.isEmpty {
                            print("┌─── 📥 A2A NON-STREAMING RESPONSE ────────────")
                            print("│ Message: \"\(msgText.prefix(200))\"")
                            print("└───────────────────────────────────────────────")
                            continuation.yield(.text(msgText, append: false))
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

/// Events emitted by the A2A service during streaming.
enum StreamEvent: Sendable {
    case taskCreated(id: String)
    case status(String)
    case text(String, append: Bool)
}

enum A2AServiceError: Error, LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to this agent"
        }
    }
}
