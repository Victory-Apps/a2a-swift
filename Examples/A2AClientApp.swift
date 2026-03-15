// Example: SwiftUI A2A Client
//
// A complete SwiftUI app that connects to any A2A agent, discovers its capabilities,
// and sends messages with real-time streaming responses.
//
// Works with any A2A-compatible agent — Python, JavaScript, Java, .NET, or Swift.

import A2A
import Foundation
import SwiftUI

// MARK: - View Model

@MainActor
@Observable
final class A2AAgentViewModel {
    var agentURL: String = "http://localhost:8080"
    var agentCard: AgentCard?
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isConnected: Bool = false
    var isLoading: Bool = false
    var error: String?

    private var client: A2AClient?
    private var currentTaskId: String?

    // MARK: - Connect to Agent

    func connect() async {
        guard let url = URL(string: agentURL) else {
            error = "Invalid URL"
            return
        }

        isLoading = true
        error = nil
        client = A2AClient(baseURL: url)

        do {
            agentCard = try await client?.fetchAgentCard()
            isConnected = true
            messages.append(ChatMessage(
                role: .system,
                text: "Connected to \(agentCard?.name ?? "agent"). Skills: \(agentCard?.skills.map(\.name).joined(separator: ", ") ?? "none")"
            ))
        } catch {
            self.error = "Failed to connect: \(error.localizedDescription)"
            isConnected = false
        }

        isLoading = false
    }

    // MARK: - Send Message (Streaming)

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = client else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text))

        let agentMessage = ChatMessage(role: .agent, text: "")
        messages.append(agentMessage)
        let agentIndex = messages.count - 1

        isLoading = true

        do {
            var request = SendMessageRequest(
                message: Message(role: .user, parts: [.text(text)])
            )
            // Reference existing task for multi-turn
            if let taskId = currentTaskId {
                request.message.taskId = taskId
            }

            let stream = try await client.sendStreamingMessage(request)

            for try await event in stream {
                switch event {
                case .task(let task):
                    currentTaskId = task.id
                    messages[agentIndex].status = task.status.state.rawValue

                case .statusUpdate(let update):
                    messages[agentIndex].status = update.status.state.rawValue
                    if let statusMsg = update.status.message?.parts.compactMap(\.text).joined() {
                        messages[agentIndex].statusText = statusMsg
                    }

                case .artifactUpdate(let update):
                    let newText = update.artifact.parts.compactMap(\.text).joined()
                    if update.append == true {
                        messages[agentIndex].text += newText
                    } else {
                        messages[agentIndex].text = newText
                    }

                case .message(let message):
                    let text = message.parts.compactMap(\.text).joined()
                    messages[agentIndex].text += text
                }
            }
        } catch {
            messages[agentIndex].text = "Error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Send Message (Non-streaming)

    func sendMessageSync() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let client = client else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text))

        isLoading = true

        do {
            let response = try await client.sendMessage(SendMessageRequest(
                message: Message(role: .user, parts: [.text(text)])
            ))

            switch response {
            case .task(let task):
                currentTaskId = task.id
                let responseText = task.artifacts?
                    .flatMap(\.parts)
                    .compactMap(\.text)
                    .joined(separator: "\n") ?? task.status.message?.parts.compactMap(\.text).joined() ?? "No response"
                messages.append(ChatMessage(role: .agent, text: responseText))

            case .message(let message):
                let text = message.parts.compactMap(\.text).joined()
                messages.append(ChatMessage(role: .agent, text: text))
            }
        } catch {
            messages.append(ChatMessage(role: .agent, text: "Error: \(error.localizedDescription)"))
        }

        isLoading = false
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var status: String?
    var statusText: String?

    enum MessageRole {
        case user, agent, system
    }
}

// MARK: - SwiftUI Views

struct A2AClientView: View {
    @State private var viewModel = A2AAgentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Connection bar
            connectionBar

            Divider()

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
    }

    private var connectionBar: some View {
        HStack {
            TextField("Agent URL", text: $viewModel.agentURL)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isConnected)

            Button(viewModel.isConnected ? "Connected" : "Connect") {
                Task { await viewModel.connect() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isConnected || viewModel.isLoading)
        }
        .padding()
    }

    private var inputBar: some View {
        HStack {
            TextField("Message...", text: $viewModel.inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }
                .disabled(!viewModel.isConnected || viewModel.isLoading)

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: viewModel.isLoading ? "hourglass" : "paperplane.fill")
            }
            .disabled(!viewModel.isConnected || viewModel.isLoading || viewModel.inputText.isEmpty)
        }
        .padding()
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let status = message.statusText {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if message.role != .user { Spacer() }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .blue
        case .agent: return Color(.systemGray5)
        case .system: return Color(.systemGray6)
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user: return .white
        case .agent, .system: return .primary
        }
    }
}

// MARK: - App Entry Point (uncomment to run standalone)

/*
@main
struct A2AClientApp: App {
    var body: some Scene {
        WindowGroup {
            A2AClientView()
        }
    }
}
*/
