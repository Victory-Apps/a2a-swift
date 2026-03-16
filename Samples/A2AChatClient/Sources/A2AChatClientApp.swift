import SwiftUI

@main
struct A2AChatClientApp: App {
    @State private var viewModel = ChatViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 900, height: 600)
    }
}

/// App delegate that registers a bundle identifier for SPM executables.
/// Without a bundle identifier, macOS cannot manage window tabs or text input properly.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Force the process to be a regular app (foreground, Dock icon, menu bar)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
