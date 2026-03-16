import A2A
import Foundation
import SwiftUI

/// Central view model coordinating chat state, agent connections, and message routing.
@MainActor
@Observable
final class ChatViewModel {
    // MARK: - State

    var messages: [ChatMessage] = []
    var connectedAgents: [AgentConnection] = []
    var inputText: String = ""
    var isProcessing: Bool = false
    var showConnectionSheet: Bool = false
    var connectionURL: String = "http://127.0.0.1:8080"
    var connectionError: String?

    /// The agent to send messages to directly (bypassing orchestrator).
    /// When nil and Foundation Models is available, the orchestrator decides.
    var selectedAgent: AgentConnection?

    // MARK: - Services

    let a2aService: A2AService
    let orchestrator: OrchestratorService

    init() {
        let service = A2AService()
        self.a2aService = service
        self.orchestrator = OrchestratorService(a2aService: service)
    }

    var isFoundationModelsAvailable: Bool {
        orchestrator.isFoundationModelsAvailable
    }

    // MARK: - Agent Connection

    func connectToAgent() async {
        let urlString = connectionURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString) else {
            connectionError = "Invalid URL"
            return
        }

        connectionError = nil

        do {
            let card = try await a2aService.connect(to: url)
            let connection = AgentConnection(url: url, agentCard: card)
            connectedAgents.append(connection)
            orchestrator.updateAgents(connectedAgents)

            // Auto-select if first agent
            if connectedAgents.count == 1 {
                selectedAgent = connection
            }

            messages.append(ChatMessage(
                role: .system,
                text: "Connected to \(card.name). Skills: \(card.skills.map(\.name).joined(separator: ", "))"
            ))

            showConnectionSheet = false
        } catch {
            connectionError = "Failed to connect: \(error.localizedDescription)"
        }
    }

    func disconnectAgent(_ agent: AgentConnection) {
        a2aService.disconnect(from: agent.url)
        connectedAgents.removeAll { $0.id == agent.id }
        orchestrator.updateAgents(connectedAgents)

        if selectedAgent?.id == agent.id {
            selectedAgent = connectedAgents.first
        }

        messages.append(ChatMessage(
            role: .system,
            text: "Disconnected from \(agent.name)"
        ))
    }

    // MARK: - Clear History

    func clearHistory() {
        messages.removeAll()
        a2aService.clearConversationHistory()
    }

    // MARK: - Send Message

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text))

        // Create placeholder for agent response
        let agentName = selectedAgent?.name ?? "Assistant"
        messages.append(ChatMessage(
            role: .agent,
            text: "",
            agentName: agentName,
            isStreaming: true
        ))
        let responseIndex = messages.count - 1

        isProcessing = true

        do {
            let stream = orchestrator.process(
                message: text,
                selectedAgent: selectedAgent
            )

            for try await event in stream {
                switch event {
                case .delegating(let name):
                    messages[responseIndex].agentName = name

                case .status(let status):
                    // Show status as a brief indicator
                    if messages[responseIndex].text.isEmpty {
                        messages[responseIndex].text = status
                    }

                case .text(let newText, let append):
                    if append {
                        messages[responseIndex].text += newText
                    } else {
                        messages[responseIndex].text = newText
                    }
                }
            }
            print("  ✅ Stream finished normally")
        } catch {
            print("  ❌ Stream error: \(error)")
            if messages[responseIndex].text.isEmpty {
                messages[responseIndex].text = "Error: \(error.localizedDescription)"
            } else {
                messages[responseIndex].text += "\n\nError: \(error.localizedDescription)"
            }
        }

        messages[responseIndex].isStreaming = false
        isProcessing = false
    }
}
