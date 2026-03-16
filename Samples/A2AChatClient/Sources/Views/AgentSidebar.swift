import SwiftUI

struct AgentSidebar: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        List {
            Section("Connected Agents") {
                if viewModel.connectedAgents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.quaternary)
                        Text("No agents connected")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.showConnectionSheet = true
                        } label: {
                            Label("Connect an Agent", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(viewModel.connectedAgents) { agent in
                        agentRow(agent)
                            .contextMenu {
                                Button("Disconnect", role: .destructive) {
                                    viewModel.disconnectAgent(agent)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.showConnectionSheet = true
                } label: {
                    Label("Add Agent", systemImage: "plus")
                }
            }
        }
    }

    private func agentRow(_ agent: AgentConnection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(agent.isConnected ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(agent.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.disconnectAgent(agent)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Disconnect from \(agent.name)")
            }

            Text(agent.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !agent.skillNames.isEmpty {
                Text(agent.skillNames)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
