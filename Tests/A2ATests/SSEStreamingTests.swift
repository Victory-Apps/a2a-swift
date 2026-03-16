import Testing
import Foundation
@testable import A2A

/// Handler that supports streaming for SSE format tests.
struct SSETestHandler: A2AAgentHandler {
    func agentCard() async throws -> AgentCard {
        AgentCard(
            name: "SSE Test Agent",
            description: "Test",
            supportedInterfaces: [AgentInterface(url: "http://localhost:8080")],
            version: "1.0.0",
            skills: [AgentSkill(id: "test", name: "Test", description: "Test", tags: [])]
        )
    }

    func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        throw A2AError.unsupportedOperation("Use streaming")
    }

    func handleSendStreamingMessage(_ request: SendMessageRequest) async throws -> AsyncThrowingStream<StreamResponse, Error> {
        AsyncThrowingStream<StreamResponse, Error> { continuation in
            let task = A2ATask(
                id: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .working)
            )
            continuation.yield(.task(task))
            continuation.yield(.statusUpdate(TaskStatusUpdateEvent(
                taskId: "task-1",
                contextId: "ctx-1",
                status: TaskStatus(state: .completed, message: Message(role: .agent, parts: [.text("Done")]))
            )))
            continuation.finish()
        }
    }

    func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask {
        throw A2AError(code: .taskNotFound)
    }

    func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        throw A2AError(code: .taskNotFound)
    }
}

@Suite("SSE Streaming Format")
struct SSEStreamingTests {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    @Test func streamEmitsIdAndRetryFields() async throws {
        let router = A2ARouter(handler: SSETestHandler())
        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendStreamingMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        guard case .stream(let stream) = result else {
            Issue.record("Expected .stream result")
            return
        }

        var chunks: [String] = []
        for try await data in stream {
            if let str = String(data: data, encoding: .utf8) {
                chunks.append(str)
            }
        }

        #expect(chunks.count == 2)

        // First chunk should have retry: field
        let first = chunks[0]
        #expect(first.contains("retry: 3000"))
        #expect(first.contains("id: 1"))
        #expect(first.contains("data: "))

        // Second chunk should have id but no retry
        let second = chunks[1]
        #expect(!second.contains("retry:"))
        #expect(second.contains("id: 2"))
        #expect(second.contains("data: "))
    }

    @Test func streamDataIsValidJSONRPC() async throws {
        let router = A2ARouter(handler: SSETestHandler())
        let request = JSONRPCRequest(
            id: .int(42),
            method: .sendStreamingMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        guard case .stream(let stream) = result else {
            Issue.record("Expected .stream result")
            return
        }

        var parser = SSELineParser()
        var responses: [JSONRPCResponse<StreamResponse>] = []

        for try await data in stream {
            let text = String(data: data, encoding: .utf8) ?? ""
            for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
                let field = parser.parse(line: line)
                if case .data(let jsonString) = field, !jsonString.isEmpty {
                    let jsonData = jsonString.data(using: .utf8)!
                    let rpcResponse = try decoder.decode(JSONRPCResponse<StreamResponse>.self, from: jsonData)
                    responses.append(rpcResponse)
                }
            }
        }

        #expect(responses.count == 2)
        #expect(responses[0].isSuccess)
        #expect(responses[1].isSuccess)

        // First should be task, second should be status update
        if case .task(let task) = responses[0].result {
            #expect(task.id == "task-1")
            #expect(task.status.state == .working)
        } else {
            Issue.record("Expected .task response")
        }

        if case .statusUpdate(let update) = responses[1].result {
            #expect(update.status.state == .completed)
        } else {
            Issue.record("Expected .statusUpdate response")
        }

        // Parser should have tracked event IDs
        #expect(parser.lastEventId == "2")
        #expect(parser.serverRetryInterval == 3.0)
    }

    @Test func sseChunksEndWithDoubleNewline() async throws {
        let router = A2ARouter(handler: SSETestHandler())
        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendStreamingMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        guard case .stream(let stream) = result else {
            Issue.record("Expected .stream result")
            return
        }

        for try await data in stream {
            let text = String(data: data, encoding: .utf8) ?? ""
            // Each SSE event must end with \n\n per spec
            #expect(text.hasSuffix("\n\n"), "SSE chunk must end with double newline")
        }
    }

    @Test func streamingSessionStructure() async throws {
        // Test that StreamingSession correctly passes through events and state
        let (eventStream, eventContinuation) = AsyncThrowingStream<StreamResponse, Error>.makeStream()
        let (stateStream, stateContinuation) = AsyncStream<ConnectionState>.makeStream()

        let session = StreamingSession(events: eventStream, connectionState: stateStream)

        // Send some state and finish
        stateContinuation.yield(.connected)
        stateContinuation.yield(.reconnecting(attempt: 1, maxAttempts: 3))
        stateContinuation.yield(.connected)
        stateContinuation.finish()

        eventContinuation.finish()

        // Consume events (should be empty)
        for try await _ in session.events {}

        // Consume connection states
        var states: [String] = []
        for await state in session.connectionState {
            switch state {
            case .connected:
                states.append("connected")
            case .reconnecting(let attempt, let max):
                states.append("reconnecting(\(attempt)/\(max))")
            case .disconnected:
                states.append("disconnected")
            }
        }
        #expect(states == ["connected", "reconnecting(1/3)", "connected"])
    }
}
