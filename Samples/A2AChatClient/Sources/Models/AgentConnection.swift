import A2A
import Foundation

/// Represents a connected remote A2A agent.
struct AgentConnection: Identifiable, Hashable {
    static func == (lhs: AgentConnection, rhs: AgentConnection) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id = UUID()
    let url: URL
    let agentCard: AgentCard
    var isConnected: Bool = true
    var lastError: String?

    var name: String { agentCard.name }
    var supportsStreaming: Bool { agentCard.capabilities.streaming ?? false }
    var skillNames: String {
        agentCard.skills.map(\.name).joined(separator: ", ")
    }
}
