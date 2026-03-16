import SwiftUI

struct ChatView: View {
    @Environment(ChatViewModel.self) private var viewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
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
        .navigationTitle("A2A Chat")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    if viewModel.isFoundationModelsAvailable {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                                .foregroundStyle(.green)
                            Text("Apple Intelligence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .help("Apple Intelligence is routing messages to agents automatically")
                    } else if !viewModel.connectedAgents.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.blue)
                            Text("Direct")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .help("Messages are sent directly to the connected agent")
                    }

                    Button {
                        viewModel.clearHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .disabled(viewModel.messages.isEmpty)
                    .help("Clear chat history")
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Agent picker (when not using FM orchestration)
            if !viewModel.isFoundationModelsAvailable && viewModel.connectedAgents.count > 1 {
                @Bindable var vm = viewModel
                Picker("Agent", selection: $vm.selectedAgent) {
                    ForEach(viewModel.connectedAgents) { agent in
                        Text(agent.name).tag(Optional(agent))
                    }
                }
                .frame(width: 120)
            }

            TextField("Message...", text: Bindable(viewModel).inputText)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }
                .disabled(viewModel.connectedAgents.isEmpty || viewModel.isProcessing)
                .onAppear { isInputFocused = true }
                .onChange(of: viewModel.connectedAgents.count) {
                    isInputFocused = true
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: viewModel.isProcessing ? "hourglass" : "paperplane.fill")
            }
            .disabled(
                viewModel.connectedAgents.isEmpty
                || viewModel.isProcessing
                || viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
            )
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }
}
