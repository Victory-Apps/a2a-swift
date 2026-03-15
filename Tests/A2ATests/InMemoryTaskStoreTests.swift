import Testing
import Foundation
@testable import A2A

@Suite("InMemoryTaskStore")
struct InMemoryTaskStoreTests {

    @Test func createAndGetTask() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(
            contextId: "ctx-1",
            status: TaskStatus(state: .submitted),
            metadata: nil
        )
        #expect(!task.id.isEmpty)
        #expect(task.contextId == "ctx-1")
        #expect(task.status.state == .submitted)

        let fetched = try await store.getTask(id: task.id, historyLength: nil)
        #expect(fetched.id == task.id)
    }

    @Test func getTaskNotFound() async {
        let store = InMemoryTaskStore()
        do {
            _ = try await store.getTask(id: "nonexistent", historyLength: nil)
            Issue.record("Expected error")
        } catch let error as A2AError {
            #expect(error.code == .taskNotFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func updateTaskStatus() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .submitted), metadata: nil)
        let updated = try await store.updateTaskStatus(
            id: task.id,
            status: TaskStatus(state: .working)
        )
        #expect(updated.status.state == .working)
    }

    @Test func addMessage() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .working), metadata: nil)
        let msg = Message(role: .user, parts: [.text("Hello")])
        let updated = try await store.addMessage(taskId: task.id, message: msg)
        #expect(updated.history?.count == 1)
        #expect(updated.history?[0].parts[0].text == "Hello")
    }

    @Test func addArtifact() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .working), metadata: nil)
        let artifact = Artifact(parts: [.text("Result")])
        let updated = try await store.addArtifact(taskId: task.id, artifact: artifact)
        #expect(updated.artifacts?.count == 1)
    }

    @Test func appendToArtifact() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .working), metadata: nil)
        let artifact = Artifact(artifactId: "a1", parts: [.text("Part 1")])
        _ = try await store.addArtifact(taskId: task.id, artifact: artifact)
        let updated = try await store.appendToArtifact(taskId: task.id, artifactId: "a1", parts: [.text(" Part 2")])
        #expect(updated.artifacts?[0].parts.count == 2)
    }

    @Test func cancelTask() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .working), metadata: nil)
        let canceled = try await store.cancelTask(id: task.id)
        #expect(canceled.status.state == .canceled)
    }

    @Test func cancelTerminalTaskFails() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .completed), metadata: nil)
        do {
            _ = try await store.cancelTask(id: task.id)
            Issue.record("Expected error")
        } catch let error as A2AError {
            #expect(error.code == .taskNotCancelable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func listTasks() async throws {
        let store = InMemoryTaskStore()
        _ = try await store.createTask(contextId: "ctx-1", status: TaskStatus(state: .completed), metadata: nil)
        _ = try await store.createTask(contextId: "ctx-1", status: TaskStatus(state: .working), metadata: nil)
        _ = try await store.createTask(contextId: "ctx-2", status: TaskStatus(state: .completed), metadata: nil)

        let all = try await store.listTasks(contextId: nil, state: nil, pageSize: 50, pageToken: nil, historyLength: nil, includeArtifacts: false)
        #expect(all.totalSize == 3)

        let ctx1 = try await store.listTasks(contextId: "ctx-1", state: nil, pageSize: 50, pageToken: nil, historyLength: nil, includeArtifacts: false)
        #expect(ctx1.totalSize == 2)

        let completed = try await store.listTasks(contextId: nil, state: .completed, pageSize: 50, pageToken: nil, historyLength: nil, includeArtifacts: false)
        #expect(completed.totalSize == 2)
    }

    @Test func historyLengthLimit() async throws {
        let store = InMemoryTaskStore()
        let task = try await store.createTask(contextId: nil, status: TaskStatus(state: .working), metadata: nil)
        for i in 0..<5 {
            _ = try await store.addMessage(
                taskId: task.id,
                message: Message(role: .user, parts: [.text("msg \(i)")])
            )
        }
        let fetched = try await store.getTask(id: task.id, historyLength: 2)
        #expect(fetched.history?.count == 2)
        #expect(fetched.history?[0].parts[0].text == "msg 3")
        #expect(fetched.history?[1].parts[0].text == "msg 4")
    }
}
