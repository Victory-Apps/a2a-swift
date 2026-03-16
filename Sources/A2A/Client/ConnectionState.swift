import Foundation

/// Represents the state of an SSE streaming connection.
///
/// Use with ``StreamingSession/connectionState`` to monitor connection health
/// during streaming operations.
public enum ConnectionState: Sendable {
    /// The connection is active and receiving events.
    case connected

    /// The connection dropped and is being re-established.
    case reconnecting(attempt: Int, maxAttempts: Int)

    /// The connection has been permanently lost.
    case disconnected(any Error)
}
