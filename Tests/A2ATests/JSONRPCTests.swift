import Testing
import Foundation
@testable import A2A

@Suite("JSON-RPC Message Encoding/Decoding")
struct JSONRPCTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    let decoder = JSONDecoder()

    @Test func requestEncoding() throws {
        let request = JSONRPCRequest(
            id: .int(1),
            method: .sendMessage,
            params: SendMessageRequest(
                message: Message(role: .user, parts: [.text("Hello")])
            )
        )
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"jsonrpc\":\"2.0\""))
        #expect(json.contains("\"method\":\"SendMessage\""))
        #expect(json.contains("\"id\":1"))
    }

    @Test func responseSuccessDecoding() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "result": {"id": "task-1", "status": {"state": "TASK_STATE_COMPLETED"}}}
        """.data(using: .utf8)!
        let response = try decoder.decode(JSONRPCResponse<A2ATask>.self, from: json)
        #expect(response.isSuccess)
        #expect(response.result?.id == "task-1")
    }

    @Test func responseErrorDecoding() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 1, "error": {"code": -32001, "message": "Task not found"}}
        """.data(using: .utf8)!
        let response = try decoder.decode(JSONRPCResponse<A2ATask>.self, from: json)
        #expect(!response.isSuccess)
        #expect(response.error?.code == -32001)
        #expect(response.error?.message == "Task not found")
    }

    @Test func jsonRPCIdIntRoundTrip() throws {
        let id = JSONRPCId.int(42)
        let data = try encoder.encode(id)
        let decoded = try decoder.decode(JSONRPCId.self, from: data)
        #expect(decoded == .int(42))
    }

    @Test func jsonRPCIdStringRoundTrip() throws {
        let id = JSONRPCId.string("req-123")
        let data = try encoder.encode(id)
        let decoded = try decoder.decode(JSONRPCId.self, from: data)
        #expect(decoded == .string("req-123"))
    }

    @Test func rawRequestParsing() throws {
        let json = """
        {"jsonrpc": "2.0", "id": 5, "method": "GetTask", "params": {"id": "task-abc"}}
        """.data(using: .utf8)!
        let raw = try decoder.decode(RawJSONRPCRequest.self, from: json)
        #expect(raw.method == "GetTask")
        #expect(raw.id == .int(5))
        #expect(raw.params?["id"]?.stringValue == "task-abc")
    }

    @Test func allMethodNames() {
        #expect(A2AMethod.sendMessage.rawValue == "SendMessage")
        #expect(A2AMethod.sendStreamingMessage.rawValue == "SendStreamingMessage")
        #expect(A2AMethod.getTask.rawValue == "GetTask")
        #expect(A2AMethod.listTasks.rawValue == "ListTasks")
        #expect(A2AMethod.cancelTask.rawValue == "CancelTask")
        #expect(A2AMethod.subscribeToTask.rawValue == "SubscribeToTask")
        #expect(A2AMethod.createTaskPushNotificationConfig.rawValue == "CreateTaskPushNotificationConfig")
        #expect(A2AMethod.getTaskPushNotificationConfig.rawValue == "GetTaskPushNotificationConfig")
        #expect(A2AMethod.listTaskPushNotificationConfigs.rawValue == "ListTaskPushNotificationConfigs")
        #expect(A2AMethod.deleteTaskPushNotificationConfig.rawValue == "DeleteTaskPushNotificationConfig")
        #expect(A2AMethod.getExtendedAgentCard.rawValue == "GetExtendedAgentCard")
    }
}
