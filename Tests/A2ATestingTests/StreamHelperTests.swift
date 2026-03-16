import Testing
import Foundation
import A2ATesting

@Suite("Stream Helpers")
struct StreamHelperTests {

    @Test func collectStreamEventsGathersAll() async throws {
        let (stream, continuation) = AsyncThrowingStream<StreamResponse, Error>.makeStream()
        continuation.yield(.task(.fixture()))
        continuation.yield(.statusUpdate(.fixture(status: .fixture(state: .working))))
        continuation.yield(.statusUpdate(.fixture(status: .fixture(state: .completed))))
        continuation.finish()

        let events = try await collectStreamEvents(stream)
        #expect(events.count == 3)
    }

    @Test func tasksFilter() {
        let events: [StreamResponse] = [
            .task(.fixture(id: "t1")),
            .statusUpdate(.fixture()),
            .task(.fixture(id: "t2")),
        ]
        let tasks = events.tasks
        #expect(tasks.count == 2)
        #expect(tasks[0].id == "t1")
        #expect(tasks[1].id == "t2")
    }

    @Test func statusUpdatesFilter() {
        let events: [StreamResponse] = [
            .task(.fixture()),
            .statusUpdate(.fixture(status: .fixture(state: .working))),
            .statusUpdate(.fixture(status: .fixture(state: .completed))),
        ]
        let updates = events.statusUpdates
        #expect(updates.count == 2)
        #expect(updates[0].status.state == .working)
        #expect(updates[1].status.state == .completed)
    }

    @Test func artifactUpdatesFilter() {
        let events: [StreamResponse] = [
            .task(.fixture()),
            .artifactUpdate(.fixture()),
            .statusUpdate(.fixture()),
        ]
        #expect(events.artifactUpdates.count == 1)
    }

    @Test func messagesFilter() {
        let events: [StreamResponse] = [
            .message(.fixture(text: "Hello")),
            .task(.fixture()),
            .message(.fixture(text: "World")),
        ]
        let msgs = events.messages
        #expect(msgs.count == 2)
        #expect(msgs[0].parts[0].text == "Hello")
    }

    @Test func taskAtIndex() throws {
        let events: [StreamResponse] = [
            .task(.fixture(id: "first")),
            .statusUpdate(.fixture()),
        ]
        let task = try events.task(at: 0)
        #expect(task.id == "first")
    }

    @Test func taskAtIndexThrowsForWrongType() {
        let events: [StreamResponse] = [
            .statusUpdate(.fixture()),
        ]
        #expect(throws: StreamAssertionError.self) {
            _ = try events.task(at: 0)
        }
    }

    @Test func taskAtIndexThrowsForOutOfBounds() {
        let events: [StreamResponse] = []
        #expect(throws: StreamAssertionError.self) {
            _ = try events.task(at: 0)
        }
    }

    @Test func statusUpdateAtIndex() throws {
        let events: [StreamResponse] = [
            .task(.fixture()),
            .statusUpdate(.fixture(status: .fixture(state: .completed))),
        ]
        let update = try events.statusUpdate(at: 1)
        #expect(update.status.state == .completed)
    }

    @Test func containsStatusFindsMatch() {
        let events: [StreamResponse] = [
            .statusUpdate(.fixture(status: .fixture(state: .working))),
            .statusUpdate(.fixture(status: .fixture(state: .completed))),
        ]
        #expect(events.containsStatus(.completed))
        #expect(events.containsStatus(.working))
        #expect(!events.containsStatus(.failed))
    }

    @Test func emptyEventsReturnEmptyFilters() {
        let events: [StreamResponse] = []
        #expect(events.tasks.isEmpty)
        #expect(events.statusUpdates.isEmpty)
        #expect(events.artifactUpdates.isEmpty)
        #expect(events.messages.isEmpty)
        #expect(!events.containsStatus(.completed))
    }
}
