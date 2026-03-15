import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends push notifications to configured webhook URLs when task events occur.
public final class PushNotificationSender: Sendable {
    private let session: URLSession
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
    }

    /// Sends a stream response event to a push notification webhook.
    public func send(
        _ event: StreamResponse,
        to config: TaskPushNotificationConfig
    ) async {
        guard let url = URL(string: config.url) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Apply authentication
        if let auth = config.authentication {
            switch auth.scheme.lowercased() {
            case "bearer":
                if let credentials = auth.credentials {
                    request.setValue("Bearer \(credentials)", forHTTPHeaderField: "Authorization")
                }
            case "basic":
                if let credentials = auth.credentials {
                    request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
                }
            default:
                if let credentials = auth.credentials {
                    request.setValue("\(auth.scheme) \(credentials)", forHTTPHeaderField: "Authorization")
                }
            }
        }

        // Include the client token if provided
        if let token = config.token {
            request.setValue(token, forHTTPHeaderField: "X-A2A-Token")
        }

        do {
            request.httpBody = try encoder.encode(event)
            _ = try await session.data(for: request)
        } catch {
            // Push notifications are fire-and-forget; log errors but don't propagate
        }
    }
}
