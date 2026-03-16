import Foundation

/// A message displayed in the chat UI.
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    /// Name of the agent that sent this message, if applicable.
    var agentName: String?
    let timestamp: Date
    /// Whether the message is still being streamed.
    var isStreaming: Bool

    enum Role: Sendable {
        case user
        case agent
        case system
    }

    init(role: Role, text: String, agentName: String? = nil, isStreaming: Bool = false) {
        self.role = role
        self.text = text
        self.agentName = agentName
        self.timestamp = Date()
        self.isStreaming = isStreaming
    }
}
