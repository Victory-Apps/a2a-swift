import Foundation

extension Part {
    /// Creates a fixture `Part` with sensible defaults for testing.
    public static func fixture(
        text: String = "Test content"
    ) -> Part {
        .text(text)
    }
}

extension Artifact {
    /// Creates a fixture `Artifact` with sensible defaults for testing.
    public static func fixture(
        artifactId: String = UUID().uuidString,
        name: String? = nil,
        description: String? = nil,
        parts: [Part] = [.text("Test artifact content")]
    ) -> Artifact {
        Artifact(
            artifactId: artifactId,
            name: name,
            description: description,
            parts: parts
        )
    }
}
