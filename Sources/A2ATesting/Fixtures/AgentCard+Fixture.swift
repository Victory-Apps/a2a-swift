extension AgentCard {
    /// Creates a fixture `AgentCard` with sensible defaults for testing.
    public static func fixture(
        name: String = "Test Agent",
        description: String = "A test agent",
        url: String = "http://localhost:8080",
        version: String = "1.0.0",
        capabilities: AgentCapabilities = AgentCapabilities(streaming: true),
        defaultInputModes: [String] = ["text/plain"],
        defaultOutputModes: [String] = ["text/plain"],
        skills: [AgentSkill] = [.fixture()]
    ) -> AgentCard {
        AgentCard(
            name: name,
            description: description,
            supportedInterfaces: [AgentInterface.fixture(url: url)],
            version: version,
            capabilities: capabilities,
            defaultInputModes: defaultInputModes,
            defaultOutputModes: defaultOutputModes,
            skills: skills
        )
    }
}

extension AgentSkill {
    /// Creates a fixture `AgentSkill` with sensible defaults for testing.
    public static func fixture(
        id: String = "test-skill",
        name: String = "Test Skill",
        description: String = "A test skill",
        tags: [String] = ["test"]
    ) -> AgentSkill {
        AgentSkill(
            id: id,
            name: name,
            description: description,
            tags: tags
        )
    }
}

extension AgentInterface {
    /// Creates a fixture `AgentInterface` with sensible defaults for testing.
    public static func fixture(
        url: String = "http://localhost:8080",
        protocolVersion: String = "1.0"
    ) -> AgentInterface {
        AgentInterface(
            url: url,
            protocolVersion: protocolVersion
        )
    }
}
