import Foundation

/// Represents a piece of content within a Message or Artifact.
/// A Part can contain text, raw binary data, a URL, or structured data.
public struct Part: Codable, Sendable, Hashable {
    /// Text content.
    public var text: String?

    /// Raw binary data (base64-encoded in JSON).
    public var raw: Data?

    /// URL pointing to file content.
    public var url: String?

    /// Structured JSON data.
    public var data: JSONValue?

    /// Optional metadata.
    public var metadata: [String: JSONValue]?

    /// Optional filename.
    public var filename: String?

    /// MIME type (e.g., "image/png").
    public var mediaType: String?

    public init(
        text: String? = nil,
        raw: Data? = nil,
        url: String? = nil,
        data: JSONValue? = nil,
        metadata: [String: JSONValue]? = nil,
        filename: String? = nil,
        mediaType: String? = nil
    ) {
        self.text = text
        self.raw = raw
        self.url = url
        self.data = data
        self.metadata = metadata
        self.filename = filename
        self.mediaType = mediaType
    }

    // MARK: - Convenience initializers

    /// Creates a text part.
    public static func text(_ text: String, metadata: [String: JSONValue]? = nil) -> Part {
        Part(text: text, metadata: metadata)
    }

    /// Creates a raw binary data part.
    public static func raw(_ data: Data, mediaType: String, filename: String? = nil, metadata: [String: JSONValue]? = nil) -> Part {
        Part(raw: data, metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a URL part.
    public static func url(_ url: String, mediaType: String? = nil, filename: String? = nil, metadata: [String: JSONValue]? = nil) -> Part {
        Part(url: url, metadata: metadata, filename: filename, mediaType: mediaType)
    }

    /// Creates a structured data part.
    public static func data(_ data: JSONValue, mediaType: String? = nil, metadata: [String: JSONValue]? = nil) -> Part {
        Part(data: data, metadata: metadata, mediaType: mediaType)
    }

    private enum CodingKeys: String, CodingKey {
        case text, raw, url, data, metadata, filename, mediaType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.raw = try container.decodeIfPresent(Data.self, forKey: .raw)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.data = try container.decodeIfPresent(JSONValue.self, forKey: .data)
        self.metadata = try container.decodeIfPresent([String: JSONValue].self, forKey: .metadata)
        self.filename = try container.decodeIfPresent(String.self, forKey: .filename)
        self.mediaType = try container.decodeIfPresent(String.self, forKey: .mediaType)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(raw, forKey: .raw)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
    }
}
