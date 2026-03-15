import Foundation

/// An output artifact produced by a task.
public struct Artifact: Codable, Sendable, Hashable {
    /// Unique identifier within the task.
    public var artifactId: String

    /// Human-readable name.
    public var name: String?

    /// Description of the artifact.
    public var description: String?

    /// Content parts (at least one required).
    public var parts: [Part]

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    /// Extension URIs.
    public var extensions: [String]?

    public init(
        artifactId: String = UUID().uuidString,
        name: String? = nil,
        description: String? = nil,
        parts: [Part],
        metadata: [String: JSONValue]? = nil,
        extensions: [String]? = nil
    ) {
        self.artifactId = artifactId
        self.name = name
        self.description = description
        self.parts = parts
        self.metadata = metadata
        self.extensions = extensions
    }
}
