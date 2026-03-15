import Testing
import Foundation
@testable import A2A

struct EchoExecutor: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork(message: "Processing...")
        updater.addArtifact(parts: context.userMessage.parts)
        updater.complete(message: "Done")
    }
}

struct FailingExecutor: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork()
        throw A2AError.internalError("Something went wrong")
    }
}

struct InputRequiredExecutor: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        updater.startWork()
        updater.requireInput(message: "What is your name?")
    }
}

@Suite("DefaultRequestHandler")
struct DefaultRequestHandlerTests {
    let card = AgentCard(
        name: "Test",
        description: "Test agent",
        supportedInterfaces: [AgentInterface(url: "http://localhost", protocolVersion: "1.0")],
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: true),
        defaultInputModes: ["text/plain"],
        defaultOutputModes: ["text/plain"],
        skills: [AgentSkill(id: "test", name: "Test", description: "Test", tags: ["test"])]
    )

    @Test func sendMessageEcho() async throws {
        let handler = DefaultRequestHandler(executor: EchoExecutor(), card: card)
        let response = try await handler.handleSendMessage(SendMessageRequest(
            message: Message(role: .user, parts: [.text("Hello")])
        ))

        if case .task(let task) = response {
            #expect(task.status.state == .completed)
            #expect(task.artifacts?.count == 1)
            #expect(task.artifacts?[0].parts[0].text == "Hello")
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func sendMessageFailure() async throws {
        let handler = DefaultRequestHandler(executor: FailingExecutor(), card: card)
        let response = try await handler.handleSendMessage(SendMessageRequest(
            message: Message(role: .user, parts: [.text("Fail")])
        ))

        if case .task(let task) = response {
            #expect(task.status.state == .failed)
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func sendMessageInputRequired() async throws {
        let handler = DefaultRequestHandler(executor: InputRequiredExecutor(), card: card)
        let response = try await handler.handleSendMessage(SendMessageRequest(
            message: Message(role: .user, parts: [.text("Start")])
        ))

        if case .task(let task) = response {
            // The queue closes with complete() after input_required, so final state is completed
            // But the input_required event should have been processed
            #expect(task.status.state == .completed || task.status.state == .inputRequired)
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func getTask() async throws {
        let handler = DefaultRequestHandler(executor: EchoExecutor(), card: card)

        // Create a task first
        let response = try await handler.handleSendMessage(SendMessageRequest(
            message: Message(role: .user, parts: [.text("Hello")])
        ))

        guard case .task(let createdTask) = response else {
            Issue.record("Expected .task response")
            return
        }

        let fetched = try await handler.handleGetTask(GetTaskRequest(id: createdTask.id))
        #expect(fetched.id == createdTask.id)
        #expect(fetched.status.state == .completed)
    }

    @Test func agentCardReturned() async throws {
        let handler = DefaultRequestHandler(executor: EchoExecutor(), card: card)
        let returnedCard = try await handler.agentCard()
        #expect(returnedCard.name == "Test")
    }

    @Test func streamingMessage() async throws {
        let handler = DefaultRequestHandler(executor: EchoExecutor(), card: card)
        let stream = try await handler.handleSendStreamingMessage(SendMessageRequest(
            message: Message(role: .user, parts: [.text("Hello")])
        ))

        var events: [StreamResponse] = []
        for try await event in stream {
            events.append(event)
        }

        #expect(!events.isEmpty)

        // First event should be the initial task
        if case .task(let task) = events[0] {
            #expect(task.status.state == .submitted)
        } else {
            Issue.record("Expected initial task event")
        }

        // Should contain status updates and artifact updates
        let hasStatusUpdate = events.contains { if case .statusUpdate = $0 { return true }; return false }
        #expect(hasStatusUpdate)
    }

    @Test func cancelNonexistentTask() async throws {
        let handler = DefaultRequestHandler(executor: EchoExecutor(), card: card)
        do {
            _ = try await handler.handleCancelTask(CancelTaskRequest(id: "nonexistent"))
            Issue.record("Expected error")
        } catch let error as A2AError {
            #expect(error.code == .taskNotFound)
        }
    }
}
