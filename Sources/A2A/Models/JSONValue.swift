import Foundation

/// A type-safe representation of arbitrary JSON values.
///
/// `JSONValue` is used throughout the SDK for metadata, extension parameters,
/// and other dynamic JSON fields. It conforms to Swift literal protocols for
/// ergonomic construction:
///
/// ```swift
/// let metadata: [String: JSONValue] = [
///     "source": "swift",
///     "count": 42,
///     "tags": ["a2a", "agent"],
///     "nested": ["key": "value"]
/// ]
/// ```
///
/// Access values with type-safe accessors like ``stringValue``, ``intValue``,
/// ``arrayValue``, or use subscripts for nested access.
public enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
            return
        }

        if let int = try? container.decode(Int.self) {
            self = .int(int)
            return
        }

        if let double = try? container.decode(Double.self) {
            self = .double(double)
            return
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }

        if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
            return
        }

        if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode JSON value")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    // MARK: - Convenience accessors

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        if case .int(let value) = self { return Double(value) }
        return nil
    }

    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let dict) = self { return dict[key] }
        return nil
    }

    public subscript(index: Int) -> JSONValue? {
        if case .array(let arr) = self, index >= 0, index < arr.count { return arr[index] }
        return nil
    }
}

// MARK: - ExpressibleBy conformances

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
