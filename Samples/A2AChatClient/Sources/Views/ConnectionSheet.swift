import SwiftUI

struct ConnectionSheet: View {
    @Environment(ChatViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect to A2A Agent")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Agent URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("http://localhost:8080", text: Bindable(viewModel).connectionURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { connect() }
            }

            if let error = viewModel.connectionError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Connect") {
                    connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting || viewModel.connectionURL.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func connect() {
        isConnecting = true
        Task {
            await viewModel.connectToAgent()
            isConnecting = false
        }
    }
}
