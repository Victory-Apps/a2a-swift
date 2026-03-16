import Foundation

/// Describes an A2A agent's identity, capabilities, and connection details.
///
/// The agent card is the entry point for agent discovery. Clients fetch it from
/// `https://{domain}/.well-known/agent-card.json` to learn what the agent does,
/// what skills it supports, and how to authenticate.
///
/// ```swift
/// let card = AgentCard(
///     name: "My Agent",
///     description: "Does useful things",
///     supportedInterfaces: [AgentInterface(url: "https://agent.example.com")],
///     version: "1.0.0",
///     capabilities: AgentCapabilities(streaming: true),
///     skills: [AgentSkill(id: "search", name: "Search", description: "Searches the web", tags: ["search"])]
/// )
/// ```
public struct AgentCard: Codable, Sendable, Hashable {
    /// Display name of the agent.
    public var name: String

    /// Description of what the agent does.
    public var description: String

    /// Supported interfaces, ordered by preference.
    public var supportedInterfaces: [AgentInterface]

    /// Information about the agent provider.
    public var provider: AgentProvider?

    /// Version string.
    public var version: String

    /// URL to documentation.
    public var documentationUrl: String?

    /// Agent capabilities.
    public var capabilities: AgentCapabilities

    /// Named security scheme definitions.
    public var securitySchemes: [String: SecurityScheme]?

    /// Security requirements.
    public var securityRequirements: [SecurityRequirement]?

    /// Default accepted input MIME types.
    public var defaultInputModes: [String]

    /// Default output MIME types.
    public var defaultOutputModes: [String]

    /// Skills the agent supports.
    public var skills: [AgentSkill]

    /// JWS signatures for the agent card.
    public var signatures: [AgentCardSignature]?

    /// URL to the agent's icon.
    public var iconUrl: String?

    public init(
        name: String,
        description: String,
        supportedInterfaces: [AgentInterface],
        provider: AgentProvider? = nil,
        version: String,
        documentationUrl: String? = nil,
        capabilities: AgentCapabilities = AgentCapabilities(),
        securitySchemes: [String: SecurityScheme]? = nil,
        securityRequirements: [SecurityRequirement]? = nil,
        defaultInputModes: [String] = ["text/plain"],
        defaultOutputModes: [String] = ["text/plain"],
        skills: [AgentSkill] = [],
        signatures: [AgentCardSignature]? = nil,
        iconUrl: String? = nil
    ) {
        self.name = name
        self.description = description
        self.supportedInterfaces = supportedInterfaces
        self.provider = provider
        self.version = version
        self.documentationUrl = documentationUrl
        self.capabilities = capabilities
        self.securitySchemes = securitySchemes
        self.securityRequirements = securityRequirements
        self.defaultInputModes = defaultInputModes
        self.defaultOutputModes = defaultOutputModes
        self.skills = skills
        self.signatures = signatures
        self.iconUrl = iconUrl
    }
}

/// An interface through which the agent can be reached.
public struct AgentInterface: Codable, Sendable, Hashable {
    /// The URL of the agent endpoint.
    public var url: String

    /// Protocol binding: "JSONRPC", "GRPC", or "HTTP+JSON".
    public var protocolBinding: String

    /// Optional tenant identifier.
    public var tenant: String?

    /// Protocol version (e.g. "1.0").
    public var protocolVersion: String

    public init(
        url: String,
        protocolBinding: String = "JSONRPC",
        tenant: String? = nil,
        protocolVersion: String = "1.0"
    ) {
        self.url = url
        self.protocolBinding = protocolBinding
        self.tenant = tenant
        self.protocolVersion = protocolVersion
    }
}

/// Information about the agent's provider.
public struct AgentProvider: Codable, Sendable, Hashable {
    /// Provider URL.
    public var url: String

    /// Provider organization name.
    public var organization: String

    public init(url: String, organization: String) {
        self.url = url
        self.organization = organization
    }
}

/// Agent capability flags.
public struct AgentCapabilities: Codable, Sendable, Hashable {
    /// Whether the agent supports streaming.
    public var streaming: Bool?

    /// Whether the agent supports push notifications.
    public var pushNotifications: Bool?

    /// Supported extensions.
    public var extensions: [AgentExtension]?

    /// Whether the agent provides an extended agent card.
    public var extendedAgentCard: Bool?

    public init(
        streaming: Bool? = nil,
        pushNotifications: Bool? = nil,
        extensions: [AgentExtension]? = nil,
        extendedAgentCard: Bool? = nil
    ) {
        self.streaming = streaming
        self.pushNotifications = pushNotifications
        self.extensions = extensions
        self.extendedAgentCard = extendedAgentCard
    }
}

/// An extension supported by the agent.
public struct AgentExtension: Codable, Sendable, Hashable {
    /// Extension URI.
    public var uri: String

    /// Description of the extension.
    public var description: String?

    /// Whether the extension is required.
    public var required: Bool?

    /// Extension parameters.
    public var params: [String: JSONValue]?

    public init(uri: String, description: String? = nil, required: Bool? = nil, params: [String: JSONValue]? = nil) {
        self.uri = uri
        self.description = description
        self.required = required
        self.params = params
    }

    private enum CodingKeys: String, CodingKey {
        case uri, description, params
        case required = "required"
    }
}

/// A skill that the agent can perform.
public struct AgentSkill: Codable, Sendable, Hashable {
    /// Unique skill identifier.
    public var id: String

    /// Display name.
    public var name: String

    /// Description of the skill.
    public var description: String

    /// Tags for categorization.
    public var tags: [String]

    /// Example inputs.
    public var examples: [String]?

    /// Input MIME types (overrides agent defaults).
    public var inputModes: [String]?

    /// Output MIME types (overrides agent defaults).
    public var outputModes: [String]?

    /// Skill-specific security requirements.
    public var securityRequirements: [SecurityRequirement]?

    public init(
        id: String,
        name: String,
        description: String,
        tags: [String] = [],
        examples: [String]? = nil,
        inputModes: [String]? = nil,
        outputModes: [String]? = nil,
        securityRequirements: [SecurityRequirement]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.tags = tags
        self.examples = examples
        self.inputModes = inputModes
        self.outputModes = outputModes
        self.securityRequirements = securityRequirements
    }
}

/// JWS signature for agent card verification (RFC 7515).
public struct AgentCardSignature: Codable, Sendable, Hashable {
    /// Base64url-encoded JWS Protected Header.
    public var protected: String

    /// Base64url-encoded signature.
    public var signature: String

    /// Optional unprotected header.
    public var header: [String: JSONValue]?

    public init(protected: String, signature: String, header: [String: JSONValue]? = nil) {
        self.protected = protected
        self.signature = signature
        self.header = header
    }

    private enum CodingKeys: String, CodingKey {
        case protected = "protected"
        case signature, header
    }
}
