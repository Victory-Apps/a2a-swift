import Testing
import Foundation
import A2ATesting

@Suite("Fixtures")
struct FixtureTests {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // MARK: - AgentCard

    @Test func agentCardDefaults() {
        let card = AgentCard.fixture()
        #expect(card.name == "Test Agent")
        #expect(card.description == "A test agent")
        #expect(card.version == "1.0.0")
        #expect(card.supportedInterfaces.count == 1)
        #expect(card.supportedInterfaces[0].url == "http://localhost:8080")
        #expect(card.capabilities.streaming == true)
        #expect(card.skills.count == 1)
        #expect(card.skills[0].id == "test-skill")
    }

    @Test func agentCardOverrides() {
        let card = AgentCard.fixture(
            name: "Custom Agent",
            description: "Custom description",
            url: "http://example.com",
            version: "2.0.0"
        )
        #expect(card.name == "Custom Agent")
        #expect(card.description == "Custom description")
        #expect(card.supportedInterfaces[0].url == "http://example.com")
        #expect(card.version == "2.0.0")
    }

    @Test func agentSkillDefaults() {
        let skill = AgentSkill.fixture()
        #expect(skill.id == "test-skill")
        #expect(skill.name == "Test Skill")
        #expect(skill.description == "A test skill")
        #expect(skill.tags == ["test"])
    }

    // MARK: - Message

    @Test func messageDefaults() {
        let message = Message.fixture()
        #expect(message.role == .user)
        #expect(message.parts.count == 1)
        #expect(message.parts[0].text == "Hello")
        #expect(!message.messageId.isEmpty)
    }

    @Test func messageOverrides() {
        let message = Message.fixture(role: .agent, text: "Response")
        #expect(message.role == .agent)
        #expect(message.parts[0].text == "Response")
    }

    @Test func messageWithCustomParts() {
        let message = Message.fixture(parts: [.text("A"), .text("B")])
        #expect(message.parts.count == 2)
        #expect(message.parts[0].text == "A")
        #expect(message.parts[1].text == "B")
    }

    // MARK: - Task

    @Test func taskDefaults() {
        let task = A2ATask.fixture()
        #expect(!task.id.isEmpty)
        #expect(task.status.state == .submitted)
        #expect(task.artifacts == nil)
        #expect(task.history == nil)
    }

    @Test func taskOverrides() {
        let task = A2ATask.fixture(
            id: "custom-id",
            status: .fixture(state: .completed)
        )
        #expect(task.id == "custom-id")
        #expect(task.status.state == .completed)
    }

    @Test func taskStatusDefaults() {
        let status = TaskStatus.fixture()
        #expect(status.state == .submitted)
        #expect(status.message == nil)
    }

    @Test func taskStatusOverrides() {
        let status = TaskStatus.fixture(state: .working, message: .fixture(text: "In progress"))
        #expect(status.state == .working)
        #expect(status.message?.parts[0].text == "In progress")
    }

    // MARK: - Part & Artifact

    @Test func partFixture() {
        let part = Part.fixture()
        #expect(part.text == "Test content")
    }

    @Test func partFixtureOverride() {
        let part = Part.fixture(text: "Custom")
        #expect(part.text == "Custom")
    }

    @Test func artifactDefaults() {
        let artifact = Artifact.fixture()
        #expect(!artifact.artifactId.isEmpty)
        #expect(artifact.parts.count == 1)
        #expect(artifact.parts[0].text == "Test artifact content")
    }

    // MARK: - Events

    @Test func taskStatusUpdateEventDefaults() {
        let event = TaskStatusUpdateEvent.fixture()
        #expect(event.taskId == "test-task")
        #expect(event.contextId == "test-context")
        #expect(event.status.state == .submitted)
    }

    @Test func taskArtifactUpdateEventDefaults() {
        let event = TaskArtifactUpdateEvent.fixture()
        #expect(event.taskId == "test-task")
        #expect(event.contextId == "test-context")
        #expect(event.artifact.parts.count == 1)
    }

    // MARK: - Request Context

    @Test func requestContextDefaults() {
        let context = RequestContext.fixture()
        #expect(context.isNewTask)
        #expect(context.userMessage.role == .user)
        #expect(context.task.status.state == .submitted)
    }

    @Test func sendMessageRequestDefaults() {
        let request = SendMessageRequest.fixture()
        #expect(request.message.role == .user)
        #expect(request.configuration == nil)
    }

    // MARK: - JSON Round-trip

    @Test func fixturesAreEncodable() throws {
        _ = try encoder.encode(AgentCard.fixture())
        _ = try encoder.encode(Message.fixture())
        _ = try encoder.encode(A2ATask.fixture())
        _ = try encoder.encode(Artifact.fixture())
        _ = try encoder.encode(TaskStatusUpdateEvent.fixture())
        _ = try encoder.encode(TaskArtifactUpdateEvent.fixture())
    }

    @Test func fixturesRoundTrip() throws {
        let card = AgentCard.fixture()
        let data = try encoder.encode(card)
        let decoded = try decoder.decode(AgentCard.self, from: data)
        #expect(decoded.name == card.name)
        #expect(decoded.version == card.version)
    }
}
