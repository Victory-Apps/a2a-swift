import Foundation

/// A streaming session that provides both A2A events and connection state updates.
///
/// Use this type to monitor connection health during streaming operations.
/// Obtain a `StreamingSession` via ``A2AClient/sendStreamingMessageWithSession(_:)``
/// or ``A2AClient/subscribeToTaskWithSession(_:)``.
///
/// ```swift
/// let session = try await client.sendStreamingMessageWithSession(request)
///
/// // Monitor connection state in a separate task
/// Task {
///     for await state in session.connectionState {
///         switch state {
///         case .connected:
///             print("Connected")
///         case .reconnecting(let attempt, let max):
///             print("Reconnecting (\(attempt)/\(max))...")
///         case .disconnected(let error):
///             print("Disconnected: \(error)")
///         }
///     }
/// }
///
/// // Consume events
/// for try await event in session.events {
///     // handle event
/// }
/// ```
public struct StreamingSession: Sendable {
    /// The stream of A2A events.
    public let events: AsyncThrowingStream<StreamResponse, Error>

    /// Connection state changes during the streaming session.
    public let connectionState: AsyncStream<ConnectionState>
}
