import Testing
import Foundation
@testable import A2A
@testable import A2AVapor
import Vapor
import VaporTesting

/// Minimal handler for Vapor integration tests.
struct VaporTestHandler: A2AAgentHandler {
    func agentCard() async throws -> AgentCard {
        AgentCard(
            name: "Vapor Test Agent",
            description: "A test agent for Vapor integration",
            supportedInterfaces: [
                AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
            ],
            version: "1.0.0",
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain"],
            skills: [
                AgentSkill(id: "test", name: "Test", description: "Test skill", tags: ["test"])
            ]
        )
    }

    func handleSendMessage(_ request: SendMessageRequest) async throws -> SendMessageResponse {
        let task = A2ATask(
            id: "test-task-1",
            contextId: request.message.contextId ?? "ctx-1",
            status: TaskStatus(state: .completed, message: Message(
                role: .agent,
                parts: [.text("Echo: \(request.message.parts.first!)")]
            ))
        )
        return .task(task)
    }

    func handleGetTask(_ request: GetTaskRequest) async throws -> A2ATask {
        throw A2AError(code: .taskNotFound, message: "Task not found: \(request.id)")
    }

    func handleCancelTask(_ request: CancelTaskRequest) async throws -> A2ATask {
        throw A2AError(code: .taskNotFound, message: "Task not found: \(request.id)")
    }
}

@Suite("A2AVapor Integration")
struct A2AVaporTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    let decoder = JSONDecoder()

    @Test func agentCardEndpoint() async throws {
        let app = try await Application.make(.testing)
        app.mountA2A(handler: VaporTestHandler())

        let tester = try app.testing()

        try await tester.test(.GET, ".well-known/agent-card.json") { res async throws in
            #expect(res.status == .ok)
            #expect(res.headers.contentType?.type == "application")
            #expect(res.headers.contentType?.subType == "json")

            let data = Data(res.body.readableBytesView)
            let card = try JSONDecoder().decode(AgentCard.self, from: data)
            #expect(card.name == "Vapor Test Agent")
            #expect(card.skills.count == 1)
        }

        try await app.asyncShutdown()
    }

    @Test func jsonRPCEndpoint() async throws {
        let app = try await Application.make(.testing)
        app.mountA2A(handler: VaporTestHandler())

        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)

        let tester = try app.testing()

        try await tester.test(.POST, "/", headers: ["content-type": "application/json"], body: ByteBuffer(data: body)) { res async throws in
            #expect(res.status == .ok)

            let data = Data(res.body.readableBytesView)
            let response = try self.decoder.decode(JSONRPCResponse<SendMessageResponse>.self, from: data)
            #expect(response.isSuccess)
        }

        try await app.asyncShutdown()
    }

    @Test func jsonRPCParseError() async throws {
        let app = try await Application.make(.testing)
        app.mountA2A(handler: VaporTestHandler())

        let tester = try app.testing()

        try await tester.test(.POST, "/", headers: ["content-type": "application/json"], body: ByteBuffer(string: "not json")) { res async throws in
            #expect(res.status == .ok)

            let data = Data(res.body.readableBytesView)
            let response = try self.decoder.decode(JSONRPCResponse<JSONValue>.self, from: data)
            #expect(response.error?.code == A2AErrorCode.parseError.rawValue)
        }

        try await app.asyncShutdown()
    }

    @Test func customPath() async throws {
        let app = try await Application.make(.testing)
        app.mountA2A(handler: VaporTestHandler(), path: "a2a")

        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let body = try encoder.encode(request)

        let tester = try app.testing()

        try await tester.test(.POST, "a2a", headers: ["content-type": "application/json"], body: ByteBuffer(data: body)) { res async throws in
            #expect(res.status == .ok)

            let data = Data(res.body.readableBytesView)
            let response = try self.decoder.decode(JSONRPCResponse<SendMessageResponse>.self, from: data)
            #expect(response.isSuccess)
        }

        try await app.asyncShutdown()
    }

    @Test func routerOverload() async throws {
        let app = try await Application.make(.testing)
        let router = A2ARouter(handler: VaporTestHandler())
        app.mountA2A(router: router)

        let tester = try app.testing()

        try await tester.test(.GET, ".well-known/agent-card.json") { res async throws in
            #expect(res.status == .ok)

            let data = Data(res.body.readableBytesView)
            let card = try JSONDecoder().decode(AgentCard.self, from: data)
            #expect(card.name == "Vapor Test Agent")
        }

        try await app.asyncShutdown()
    }
}
