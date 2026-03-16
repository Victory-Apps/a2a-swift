import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Orchestrates message routing using Apple Foundation Models on-device.
///
/// When Foundation Models is available, the on-device LLM decides whether to:
/// - Answer the user's question directly
/// - Delegate to a connected A2A agent based on its capabilities
///
/// When unavailable, falls back to manual agent selection.
@MainActor
final class OrchestratorService {
    private let a2aService: A2AService
    private var agents: [AgentConnection] = []

    init(a2aService: A2AService) {
        self.a2aService = a2aService
    }

    func updateAgents(_ agents: [AgentConnection]) {
        self.agents = agents
    }

    var isFoundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Processes a user message, deciding whether to handle locally or delegate.
    ///
    /// Returns an async stream of text chunks for the response.
    func process(
        message: String,
        selectedAgent: AgentConnection? = nil
    ) -> AsyncThrowingStream<OrchestratorEvent, Error> {
        print("┌─── 🧠 ORCHESTRATOR ───────────────────────────")
        print("│ User message: \"\(message)\"")

        // If an agent is explicitly selected (manual mode), delegate directly
        if let agent = selectedAgent {
            print("│ Decision: Manual delegation → \(agent.name)")
            print("│ Agent URL: \(agent.url)")
            print("│ Streaming: \(agent.supportsStreaming)")
            print("└───────────────────────────────────────────────")
            return delegateToAgent(message: message, agent: agent)
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), isFoundationModelsAvailable {
            print("│ Decision: Using Foundation Models (on-device LLM)")
            print("│ Connected agents: \(agents.map(\.name).joined(separator: ", "))")
            print("└───────────────────────────────────────────────")
            return processWithFoundationModels(message: message)
        }
        #endif

        // Fallback: if only one agent is connected, send to it
        if let singleAgent = agents.first, agents.count == 1 {
            print("│ Decision: Auto-delegate (single agent) → \(singleAgent.name)")
            print("│ Agent URL: \(singleAgent.url)")
            print("│ Streaming: \(singleAgent.supportsStreaming)")
            print("└───────────────────────────────────────────────")
            return delegateToAgent(message: message, agent: singleAgent)
        }

        // No FM and no single agent — return an error
        return AsyncThrowingStream { continuation in
            if agents.isEmpty {
                continuation.finish(throwing: OrchestratorError.noAgentsConnected)
            } else {
                continuation.finish(throwing: OrchestratorError.selectAgentRequired)
            }
        }
    }

    // MARK: - Foundation Models Orchestration

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func processWithFoundationModels(message: String) -> AsyncThrowingStream<OrchestratorEvent, Error> {
        let agents = self.agents
        let a2aService = self.a2aService

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let systemPrompt = Self.buildSystemPrompt(agents: agents)
                    let session = LanguageModelSession(instructions: systemPrompt)

                    // Ask the FM to decide: respond directly or delegate
                    let decisionPrompt = Self.buildDecisionPrompt(
                        userMessage: message,
                        agents: agents
                    )

                    let response = try await session.respond(to: decisionPrompt)
                    let responseText = response.content

                    print("┌─── 🍎 FOUNDATION MODELS RESPONSE ────────────")
                    print("│ FM output: \"\(responseText.prefix(200))\"")

                    // Check if the FM decided to delegate
                    if let delegation = Self.parseDelegation(from: responseText, agents: agents) {
                        print("│ Decision: DELEGATE → \(delegation.name) (\(delegation.url))")
                        print("└───────────────────────────────────────────────")
                        continuation.yield(.delegating(to: delegation.name))

                        let stream = a2aService.sendMessage(
                            message,
                            to: delegation.url,
                            streaming: delegation.supportsStreaming
                        )
                        for try await event in stream {
                            guard !Task.isCancelled else { break }
                            switch event {
                            case .taskCreated:
                                break
                            case .status(let status):
                                continuation.yield(.status(status))
                            case .text(let text, let append):
                                continuation.yield(.text(text, append: append))
                            }
                        }
                    } else {
                        // FM is responding directly — stream its response
                        print("│ Decision: RESPOND DIRECTLY (no delegation)")
                        print("└───────────────────────────────────────────────")
                        continuation.yield(.text(responseText, append: false))
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

    private static func buildSystemPrompt(agents: [AgentConnection]) -> String {
        var prompt = """
        You are a helpful assistant that can either answer questions directly \
        or delegate tasks to specialized AI agents.

        """

        if !agents.isEmpty {
            prompt += "\nAvailable agents:\n"
            for (index, agent) in agents.enumerated() {
                let skills = agent.agentCard.skills.map { "\($0.name): \($0.description)" }.joined(separator: "; ")
                prompt += """
                \(index + 1). "\(agent.name)" at \(agent.url.absoluteString)
                   Description: \(agent.agentCard.description)
                   Skills: \(skills)

                """
            }
            prompt += """

            If the user's request matches an agent's skills, respond with EXACTLY:
            DELEGATE: <agent_url>

            Otherwise, answer the question directly yourself.
            """
        }

        return prompt
    }

    private static func buildDecisionPrompt(userMessage: String, agents: [AgentConnection]) -> String {
        if agents.isEmpty {
            return userMessage
        }
        return """
        User request: \(userMessage)

        Should you handle this yourself or delegate to one of the available agents? \
        If delegating, respond with DELEGATE: <agent_url>. Otherwise, respond directly.
        """
    }

    private static func parseDelegation(from response: String, agents: [AgentConnection]) -> AgentConnection? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("DELEGATE:") else { return nil }
        let urlString = String(trimmed.dropFirst("DELEGATE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString) else { return nil }
        return agents.first { $0.url == url }
    }
    #endif

    // MARK: - Direct Delegation

    private func delegateToAgent(message: String, agent: AgentConnection) -> AsyncThrowingStream<OrchestratorEvent, Error> {
        let a2aService = self.a2aService

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.delegating(to: agent.name))

                    let stream = a2aService.sendMessage(message, to: agent.url, streaming: agent.supportsStreaming)
                    for try await event in stream {
                        guard !Task.isCancelled else { break }
                        switch event {
                        case .taskCreated:
                            break
                        case .status(let status):
                            continuation.yield(.status(status))
                        case .text(let text, let append):
                            continuation.yield(.text(text, append: append))
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

/// Events emitted by the orchestrator during processing.
enum OrchestratorEvent: Sendable {
    case delegating(to: String)
    case status(String)
    case text(String, append: Bool)
}

enum OrchestratorError: Error, LocalizedError {
    case noAgentsConnected
    case selectAgentRequired

    var errorDescription: String? {
        switch self {
        case .noAgentsConnected:
            return "No agents connected. Add an agent first."
        case .selectAgentRequired:
            return "Multiple agents connected. Please select one or enable Apple Intelligence for automatic routing."
        }
    }
}
