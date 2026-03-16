import Foundation

/// Internal parser for Server-Sent Events (SSE) lines.
///
/// Handles the SSE protocol fields: `data:`, `id:`, `retry:`, and `event:`.
/// Tracks the last event ID and server-suggested retry interval for reconnection.
struct SSELineParser: Sendable {
    /// The last received event ID, used for `Last-Event-ID` header on reconnect.
    private(set) var lastEventId: String?

    /// Server-suggested retry interval in seconds, if received.
    private(set) var serverRetryInterval: TimeInterval?

    enum Field: Sendable, Equatable {
        case data(String)
        case id(String)
        case retry(Int)
        case event(String)
        case comment
        case empty
    }

    /// Parses a single SSE line and returns the field type.
    mutating func parse(line: String) -> Field {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return .empty
        }

        if trimmed.hasPrefix(":") {
            return .comment
        }

        if trimmed.hasPrefix("data:") {
            let value = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return .data(value)
        }

        if trimmed.hasPrefix("id:") {
            let value = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            lastEventId = value
            return .id(value)
        }

        if trimmed.hasPrefix("retry:") {
            let value = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if let ms = Int(value) {
                serverRetryInterval = TimeInterval(ms) / 1000.0
                return .retry(ms)
            }
            return .comment
        }

        if trimmed.hasPrefix("event:") {
            let value = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return .event(value)
        }

        return .comment
    }
}
