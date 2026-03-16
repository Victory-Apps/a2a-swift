import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let agentName = message.agentName, message.role == .agent {
                    Text(agentName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text(message.text.isEmpty ? " " : message.text)
                        .textSelection(.enabled)

                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .blue
        case .agent: return Color(nsColor: .controlBackgroundColor)
        case .system: return Color(nsColor: .windowBackgroundColor)
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user: return .white
        case .agent, .system: return .primary
        }
    }
}
