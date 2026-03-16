import SwiftUI

struct ContentView: View {
    @Environment(ChatViewModel.self) private var viewModel

    var body: some View {
        NavigationSplitView {
            AgentSidebar()
        } detail: {
            ChatView()
        }
        .sheet(isPresented: Bindable(viewModel).showConnectionSheet) {
            ConnectionSheet()
        }
    }
}
