import Testing
import Foundation
import A2ATesting

@Suite("MockA2AClient")
struct MockClientTests {

    @Test func returnsConfiguredAgentCard() async throws {
        let client = MockA2AClient()
        let card = AgentCard.fixture(name: "Custom")
        await client.setAgentCard(card)

        let result = try await client.fetchAgentCard()
        #expect(result.name == "Custom")

        let count = await client.fetchAgentCardCallCount
        #expect(count == 1)
    }

    @Test func returnsConfiguredSendMessageResponse() async throws {
        let client = MockA2AClient()
        let task = A2ATask.fixture(status: .fixture(state: .completed))
        await client.setSendMessageResponse(.task(task))

        let response = try await client.sendMessage(.fixture())

        if case .task(let t) = response {
            #expect(t.status.state == .completed)
        } else {
            Issue.record("Expected .task response")
        }

        let count = await client.sendMessageCallCount
        #expect(count == 1)

        let lastRequest = await client.lastSendMessageRequest
        #expect(lastRequest != nil)
    }

    @Test func returnsStreamingResponses() async throws {
        let client = MockA2AClient()
        let responses: [StreamResponse] = [
            .task(.fixture()),
            .statusUpdate(.fixture(status: .fixture(state: .completed)))
        ]
        await client.setStreamingResponses(responses)

        let stream = try await client.sendStreamingMessage(.fixture())
        let events = try await collectStreamEvents(stream)

        #expect(events.count == 2)
        #expect(events.tasks.count == 1)
        #expect(events.statusUpdates.count == 1)
    }

    @Test func returnsConfiguredGetTaskResponse() async throws {
        let client = MockA2AClient()
        let task = A2ATask.fixture(id: "my-task")
        await client.setGetTaskResponse(task)

        let result = try await client.getTask(GetTaskRequest(id: "my-task"))
        #expect(result.id == "my-task")

        let count = await client.getTaskCallCount
        #expect(count == 1)
    }

    @Test func throwsConfiguredError() async throws {
        let client = MockA2AClient()
        await client.setError(A2AError.internalError("Test error"))

        do {
            _ = try await client.fetchAgentCard()
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }

    @Test func throwsWhenNotConfigured() async throws {
        let client = MockA2AClient()

        do {
            _ = try await client.fetchAgentCard()
            Issue.record("Expected error")
        } catch let error as MockA2AClientError {
            #expect(error.description.contains("not configured"))
        }
    }

    @Test func resetClearsState() async throws {
        let client = MockA2AClient()
        await client.setAgentCard(.fixture())
        _ = try await client.fetchAgentCard()

        let countBefore = await client.fetchAgentCardCallCount
        #expect(countBefore == 1)

        await client.reset()

        let countAfter = await client.fetchAgentCardCallCount
        #expect(countAfter == 0)

        do {
            _ = try await client.fetchAgentCard()
            Issue.record("Expected error after reset")
        } catch {
            // Expected — agent card was cleared
        }
    }

    @Test func recordsMultipleCalls() async throws {
        let client = MockA2AClient()
        await client.setSendMessageResponse(.task(.fixture()))

        _ = try await client.sendMessage(.fixture(message: .fixture(text: "First")))
        _ = try await client.sendMessage(.fixture(message: .fixture(text: "Second")))

        let count = await client.sendMessageCallCount
        #expect(count == 2)

        let last = await client.lastSendMessageRequest
        #expect(last?.message.parts[0].text == "Second")
    }
}
