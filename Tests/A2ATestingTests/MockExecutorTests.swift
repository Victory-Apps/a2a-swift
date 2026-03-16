import Testing
import Foundation
import A2ATesting

@Suite("MockAgentExecutor")
struct MockExecutorTests {

    @Test func echoPreset() async throws {
        let handler = DefaultRequestHandler(
            executor: MockAgentExecutor.echo(),
            card: .fixture()
        )
        let response = try await handler.handleSendMessage(
            .fixture(message: .fixture(text: "Echo me"))
        )

        if case .task(let task) = response {
            #expect(task.status.state == .completed)
            #expect(task.artifacts?.count == 1)
            #expect(task.artifacts?[0].parts[0].text == "Echo me")
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func failingPreset() async throws {
        let handler = DefaultRequestHandler(
            executor: MockAgentExecutor.failing(),
            card: .fixture()
        )
        let response = try await handler.handleSendMessage(.fixture())

        if case .task(let task) = response {
            #expect(task.status.state == .failed)
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func completingPreset() async throws {
        let handler = DefaultRequestHandler(
            executor: MockAgentExecutor.completing(with: "Result text"),
            card: .fixture()
        )
        let response = try await handler.handleSendMessage(.fixture())

        if case .task(let task) = response {
            #expect(task.status.state == .completed)
            #expect(task.artifacts?[0].parts[0].text == "Result text")
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func inputRequiredPreset() async throws {
        let handler = DefaultRequestHandler(
            executor: MockAgentExecutor.inputRequired(message: "What is your name?"),
            card: .fixture()
        )
        let response = try await handler.handleSendMessage(.fixture())

        if case .task(let task) = response {
            #expect(task.status.state == .completed || task.status.state == .inputRequired)
        } else {
            Issue.record("Expected .task response")
        }
    }

    @Test func customClosure() async throws {
        let executor = MockAgentExecutor { _, updater in
            updater.addArtifact(parts: [.text("custom")])
            updater.complete()
        }

        let handler = DefaultRequestHandler(executor: executor, card: .fixture())
        let response = try await handler.handleSendMessage(.fixture())

        if case .task(let task) = response {
            #expect(task.status.state == .completed)
            #expect(task.artifacts?[0].parts[0].text == "custom")
        } else {
            Issue.record("Expected .task response")
        }
    }
}
