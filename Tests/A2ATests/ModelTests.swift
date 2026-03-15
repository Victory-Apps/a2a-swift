import Testing
import Foundation
@testable import A2A

@Suite("A2A Model Encoding/Decoding")
struct ModelTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    let decoder = JSONDecoder()

    // MARK: - JSONValue

    @Test func jsonValueRoundTrip() throws {
        let value: JSONValue = .object([
            "name": .string("test"),
            "count": .int(42),
            "enabled": .bool(true),
            "score": .double(3.14),
            "tags": .array([.string("a"), .string("b")]),
            "empty": .null
        ])
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test func jsonValueLiterals() {
        let s: JSONValue = "hello"
        #expect(s.stringValue == "hello")

        let i: JSONValue = 42
        #expect(i.intValue == 42)

        let b: JSONValue = true
        #expect(b.boolValue == true)

        let n: JSONValue = nil
        #expect(n.isNull)
    }

    // MARK: - Part

    @Test func textPartRoundTrip() throws {
        let part = Part.text("Hello, world!")
        let data = try encoder.encode(part)
        let decoded = try decoder.decode(Part.self, from: data)
        #expect(decoded.text == "Hello, world!")
        #expect(decoded.url == nil)
    }

    @Test func urlPartRoundTrip() throws {
        let part = Part.url("https://example.com/image.png", mediaType: "image/png", filename: "image.png")
        let data = try encoder.encode(part)
        let decoded = try decoder.decode(Part.self, from: data)
        #expect(decoded.url == "https://example.com/image.png")
        #expect(decoded.mediaType == "image/png")
        #expect(decoded.filename == "image.png")
    }

    @Test func dataPartRoundTrip() throws {
        let structured: JSONValue = .object(["key": .string("value"), "num": .int(1)])
        let part = Part.data(structured)
        let data = try encoder.encode(part)
        let decoded = try decoder.decode(Part.self, from: data)
        #expect(decoded.data?["key"]?.stringValue == "value")
    }

    // MARK: - Message

    @Test func messageRoundTrip() throws {
        let message = Message(
            messageId: "msg-1",
            contextId: "ctx-1",
            role: .user,
            parts: [.text("Hello")],
            extensions: ["urn:example:ext"]
        )
        let data = try encoder.encode(message)
        let decoded = try decoder.decode(Message.self, from: data)
        #expect(decoded.messageId == "msg-1")
        #expect(decoded.contextId == "ctx-1")
        #expect(decoded.role == .user)
        #expect(decoded.parts.count == 1)
        #expect(decoded.parts[0].text == "Hello")
        #expect(decoded.extensions == ["urn:example:ext"])
    }

    // MARK: - TaskState

    @Test func taskStateTerminal() {
        #expect(TaskState.completed.isTerminal)
        #expect(TaskState.failed.isTerminal)
        #expect(TaskState.canceled.isTerminal)
        #expect(TaskState.rejected.isTerminal)
        #expect(!TaskState.working.isTerminal)
        #expect(!TaskState.submitted.isTerminal)
        #expect(!TaskState.inputRequired.isTerminal)
    }

    @Test func taskStateInterrupted() {
        #expect(TaskState.inputRequired.isInterrupted)
        #expect(TaskState.authRequired.isInterrupted)
        #expect(!TaskState.working.isInterrupted)
        #expect(!TaskState.completed.isInterrupted)
    }

    @Test func taskStateEncoding() throws {
        let state = TaskState.completed
        let data = try encoder.encode(state)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("TASK_STATE_COMPLETED"))
    }

    // MARK: - Task

    @Test func taskRoundTrip() throws {
        let task = A2ATask(
            id: "task-1",
            contextId: "ctx-1",
            status: TaskStatus(state: .working, message: Message(role: .agent, parts: [.text("Processing...")])),
            artifacts: [Artifact(artifactId: "a-1", parts: [.text("Result")])],
            history: [Message(role: .user, parts: [.text("Do something")])]
        )
        let data = try encoder.encode(task)
        let decoded = try decoder.decode(A2ATask.self, from: data)
        #expect(decoded.id == "task-1")
        #expect(decoded.status.state == .working)
        #expect(decoded.artifacts?.count == 1)
        #expect(decoded.history?.count == 1)
    }

    // MARK: - StreamResponse

    @Test func streamResponseTaskDecoding() throws {
        let json = """
        {"task": {"id": "t1", "status": {"state": "TASK_STATE_WORKING"}}}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(StreamResponse.self, from: json)
        if case .task(let task) = decoded {
            #expect(task.id == "t1")
            #expect(task.status.state == .working)
        } else {
            Issue.record("Expected .task")
        }
    }

    @Test func streamResponseStatusUpdateDecoding() throws {
        let json = """
        {"statusUpdate": {"taskId": "t1", "contextId": "c1", "status": {"state": "TASK_STATE_COMPLETED"}}}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(StreamResponse.self, from: json)
        if case .statusUpdate(let event) = decoded {
            #expect(event.taskId == "t1")
            #expect(event.status.state == .completed)
        } else {
            Issue.record("Expected .statusUpdate")
        }
    }

    @Test func streamResponseArtifactUpdateDecoding() throws {
        let json = """
        {"artifactUpdate": {"taskId": "t1", "contextId": "c1", "artifact": {"artifactId": "a1", "parts": [{"text": "chunk"}]}, "append": true, "lastChunk": false}}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(StreamResponse.self, from: json)
        if case .artifactUpdate(let event) = decoded {
            #expect(event.taskId == "t1")
            #expect(event.artifact.parts[0].text == "chunk")
            #expect(event.append == true)
            #expect(event.lastChunk == false)
        } else {
            Issue.record("Expected .artifactUpdate")
        }
    }

    // MARK: - SendMessageResponse

    @Test func sendMessageResponseTaskDecoding() throws {
        let json = """
        {"task": {"id": "t1", "status": {"state": "TASK_STATE_COMPLETED"}}}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(SendMessageResponse.self, from: json)
        if case .task(let task) = decoded {
            #expect(task.status.state == .completed)
        } else {
            Issue.record("Expected .task")
        }
    }

    @Test func sendMessageResponseMessageDecoding() throws {
        let json = """
        {"message": {"messageId": "m1", "role": "ROLE_AGENT", "parts": [{"text": "Hi"}]}}
        """.data(using: .utf8)!
        let decoded = try decoder.decode(SendMessageResponse.self, from: json)
        if case .message(let msg) = decoded {
            #expect(msg.role == .agent)
        } else {
            Issue.record("Expected .message")
        }
    }
}
