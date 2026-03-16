/// Collects all events from a ``StreamResponse`` stream into an array.
///
/// ```swift
/// let stream = try await handler.handleSendStreamingMessage(request)
/// let events = try await collectStreamEvents(stream)
/// #expect(events.count == 3)
/// ```
public func collectStreamEvents(
    _ stream: AsyncThrowingStream<StreamResponse, Error>
) async throws -> [StreamResponse] {
    var events: [StreamResponse] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}
