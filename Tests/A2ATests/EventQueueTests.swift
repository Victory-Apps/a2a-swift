import Testing
import Foundation
@testable import A2A

@Suite("EventQueue")
struct EventQueueTests {

    @Test func singleSubscriber() async {
        let queue = EventQueue()
        let subscription = queue.subscribe()

        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: "t1", contextId: "c1",
            status: TaskStatus(state: .working)
        )))
        queue.close()

        var events: [AgentEvent] = []
        for await event in subscription {
            events.append(event)
        }

        // Should receive the status update + completed
        #expect(events.count == 2)
        if case .statusUpdate(let update) = events[0] {
            #expect(update.status.state == .working)
        } else {
            Issue.record("Expected statusUpdate")
        }
        if case .completed = events[1] {
            // OK
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test func multipleSubscribers() async {
        let queue = EventQueue()
        let sub1 = queue.subscribe()
        let sub2 = queue.subscribe()

        queue.enqueue(.message(Message(role: .agent, parts: [.text("Hello")])))
        queue.close()

        var count1 = 0
        for await _ in sub1 { count1 += 1 }
        var count2 = 0
        for await _ in sub2 { count2 += 1 }

        // Both subscribers should get message + completed
        #expect(count1 == 2)
        #expect(count2 == 2)
    }

    @Test func subscribingToClosedQueue() async {
        let queue = EventQueue()
        queue.close()
        let subscription = queue.subscribe()

        var events: [AgentEvent] = []
        for await event in subscription {
            events.append(event)
        }

        // Should immediately get completed
        #expect(events.count == 1)
        if case .completed = events[0] {
            // OK
        } else {
            Issue.record("Expected completed")
        }
    }

    @Test func closedProperty() {
        let queue = EventQueue()
        #expect(!queue.closed)
        queue.close()
        #expect(queue.closed)
    }

    @Test func enqueuingToClosedQueueIsNoOp() async {
        let queue = EventQueue()
        let subscription = queue.subscribe()
        queue.close()
        queue.enqueue(.message(Message(role: .agent, parts: [.text("Late")])))

        var count = 0
        for await _ in subscription { count += 1 }
        // Should only get the completed event, not the late message
        #expect(count == 1)
    }

    @Test func streamResponseSequence() async {
        let queue = EventQueue()
        let responses = queue.streamResponses(taskId: "t1", contextId: "c1")

        queue.enqueue(.statusUpdate(TaskStatusUpdateEvent(
            taskId: "t1", contextId: "c1",
            status: TaskStatus(state: .working)
        )))
        queue.enqueue(.artifactUpdate(TaskArtifactUpdateEvent(
            taskId: "t1", contextId: "c1",
            artifact: Artifact(parts: [.text("result")])
        )))
        queue.close()

        var streamResponses: [StreamResponse] = []
        for await response in responses {
            streamResponses.append(response)
        }

        #expect(streamResponses.count == 2)
        if case .statusUpdate(let update) = streamResponses[0] {
            #expect(update.status.state == .working)
        } else {
            Issue.record("Expected statusUpdate")
        }
        if case .artifactUpdate(let update) = streamResponses[1] {
            #expect(update.artifact.parts[0].text == "result")
        } else {
            Issue.record("Expected artifactUpdate")
        }
    }
}

@Suite("EventQueueManager")
struct EventQueueManagerTests {

    @Test func getOrCreateQueue() async {
        let manager = EventQueueManager()
        let q1 = await manager.queue(for: "task-1")
        let q2 = await manager.queue(for: "task-1")
        // Same queue returned for same task
        #expect(q1 === q2)

        let q3 = await manager.queue(for: "task-2")
        // Different queue for different task
        #expect(q1 !== q3)
    }

    @Test func removeQueue() async {
        let manager = EventQueueManager()
        let q = await manager.queue(for: "task-1")
        #expect(!q.closed)

        await manager.removeQueue(for: "task-1")
        #expect(q.closed)

        let newQ = await manager.existingQueue(for: "task-1")
        #expect(newQ == nil)
    }
}
