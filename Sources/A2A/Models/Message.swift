import Foundation

/// The role of the message sender.
public enum Role: String, Codable, Sendable, Hashable {
    /// Unspecified role (default/unknown).
    case unspecified = "ROLE_UNSPECIFIED"
    /// A message from the client (human or calling agent).
    case user = "ROLE_USER"
    /// A message from the agent.
    case agent = "ROLE_AGENT"
}

/// A message exchanged between client and agent.
///
/// Messages carry one or more ``Part`` values as their content. They are used both
/// as input (from the client) and in task history. Use ``Message/init(role:parts:)``
/// for simple text messages, or include structured data, files, and URLs via ``Part``.
public struct Message: Codable, Sendable, Hashable {
    /// Unique message identifier, created by the sender.
    public var messageId: String

    /// Optional context identifier for grouping related interactions.
    public var contextId: String?

    /// Optional task identifier referencing an existing task.
    public var taskId: String?

    /// The role of the message sender.
    public var role: Role

    /// The content parts of this message.
    public var parts: [Part]

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    /// Extension URIs this message uses.
    public var extensions: [String]?

    /// Task IDs referenced by this message.
    public var referenceTaskIds: [String]?

    public init(
        messageId: String = UUID().uuidString,
        contextId: String? = nil,
        taskId: String? = nil,
        role: Role,
        parts: [Part],
        metadata: [String: JSONValue]? = nil,
        extensions: [String]? = nil,
        referenceTaskIds: [String]? = nil
    ) {
        self.messageId = messageId
        self.contextId = contextId
        self.taskId = taskId
        self.role = role
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
        self.referenceTaskIds = referenceTaskIds
    }
}
