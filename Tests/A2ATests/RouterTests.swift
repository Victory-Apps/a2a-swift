import Testing
import Foundation
@testable import A2A

/// A minimal test agent handler for router tests.
struct TestAgentHandler: A2AAgentHandler {
    let store = InMemoryTaskStore()

    func agentCard() async throws -> AgentCard {
        AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
            ],
            version: "1.0.0",
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain"],
            skills: [
                AgentSkill(id: "echo", name: "Echo", description: "Echoes input", tags: ["test"])
            ]
        )
    }

    func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        let task = try await store.createTask(
            contextId: request.message.contextId,
            status: TaskStatus(state: .completed, message: Message(
                role: .agent,
                parts: request.message.parts
            )),
            metadata: nil
        )
        return .task(task)
    }

    func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask {
        try await store.getTask(id: request.id, historyLength: request.historyLength)
    }

    func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        try await store.cancelTask(id: request.id)
    }
}

@Suite("A2ARouter")
struct RouterTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    let decoder = JSONDecoder()

    @Test func routeSendMessage() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        if case .response(let data) = result {
            let response = try decoder.decode(JSONRPCResponse<SendMessageResponse>.self, from: data)
            #expect(response.isSuccess)
            if case .task(let task) = response.result {
                #expect(task.status.state == .completed)
            } else {
                Issue.record("Expected .task response")
            }
        } else {
            Issue.record("Expected .response")
        }
    }

    @Test func routeGetTaskNotFound() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let request = JSONRPCRequest(
            id: .int(2),
            method: .getTask,
            params: GetTaskRequest(id: "nonexistent")
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        if case .response(let data) = result {
            let response = try decoder.decode(JSONRPCResponse<A2ATask>.self, from: data)
            #expect(!response.isSuccess)
            #expect(response.error?.code == A2AErrorCode.taskNotFound.rawValue)
        } else {
            Issue.record("Expected .response")
        }
    }

    @Test func routeUnknownMethod() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let json = """
        {"jsonrpc": "2.0", "id": 3, "method": "UnknownMethod", "params": {}}
        """.data(using: .utf8)!
        let result = try await router.route(body: json)

        if case .response(let data) = result {
            let response = try decoder.decode(JSONRPCResponse<JSONValue>.self, from: data)
            #expect(response.error?.code == A2AErrorCode.methodNotFound.rawValue)
        } else {
            Issue.record("Expected .response")
        }
    }

    @Test func routeParseError() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let result = try await router.route(body: "not json".data(using: .utf8)!)

        if case .response(let data) = result {
            let response = try decoder.decode(JSONRPCResponse<JSONValue>.self, from: data)
            #expect(response.error?.code == A2AErrorCode.parseError.rawValue)
        } else {
            Issue.record("Expected .response")
        }
    }

    @Test func agentCardEndpoint() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let data = try await router.handleAgentCardRequest()
        let card = try decoder.decode(AgentCard.self, from: data)
        #expect(card.name == "Test Agent")
        #expect(card.skills.count == 1)
    }

    @Test func routeUnsupportedStreamingReturnsError() async throws {
        let router = A2ARouter(handler: TestAgentHandler())
        let request = JSONRPCRequest(
            id: .int(4),
            method: .sendStreamingMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)
        let result = try await router.route(body: body)

        if case .response(let data) = result {
            let response = try decoder.decode(JSONRPCResponse<JSONValue>.self, from: data)
            #expect(response.error?.code == A2AErrorCode.unsupportedOperation.rawValue)
        } else {
            Issue.record("Expected .response with error")
        }
    }
}
