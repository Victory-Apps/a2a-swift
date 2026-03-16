import Foundation

/// A security scheme definition.
public enum SecurityScheme: Codable, Sendable, Hashable {
    case apiKey(APIKeySecurityScheme)
    case httpAuth(HTTPAuthSecurityScheme)
    case oauth2(OAuth2SecurityScheme)
    case openIdConnect(OpenIdConnectSecurityScheme)
    case mutualTls(MutualTlsSecurityScheme)

    private enum CodingKeys: String, CodingKey {
        case apiKeySecurityScheme
        case httpAuthSecurityScheme
        case oauth2SecurityScheme
        case openIdConnectSecurityScheme
        case mtlsSecurityScheme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(APIKeySecurityScheme.self, forKey: .apiKeySecurityScheme) {
            self = .apiKey(value)
            return
        }
        if let value = try container.decodeIfPresent(HTTPAuthSecurityScheme.self, forKey: .httpAuthSecurityScheme) {
            self = .httpAuth(value)
            return
        }
        if let value = try container.decodeIfPresent(OAuth2SecurityScheme.self, forKey: .oauth2SecurityScheme) {
            self = .oauth2(value)
            return
        }
        if let value = try container.decodeIfPresent(OpenIdConnectSecurityScheme.self, forKey: .openIdConnectSecurityScheme) {
            self = .openIdConnect(value)
            return
        }
        if let value = try container.decodeIfPresent(MutualTlsSecurityScheme.self, forKey: .mtlsSecurityScheme) {
            self = .mutualTls(value)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown security scheme type")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .apiKey(let value):
            try container.encode(value, forKey: .apiKeySecurityScheme)
        case .httpAuth(let value):
            try container.encode(value, forKey: .httpAuthSecurityScheme)
        case .oauth2(let value):
            try container.encode(value, forKey: .oauth2SecurityScheme)
        case .openIdConnect(let value):
            try container.encode(value, forKey: .openIdConnectSecurityScheme)
        case .mutualTls(let value):
            try container.encode(value, forKey: .mtlsSecurityScheme)
        }
    }
}

/// A list of strings, used as the value type in SecurityRequirement's map.
/// Proto: `message StringList { repeated string list = 1; }`
public struct StringList: Codable, Sendable, Hashable {
    public var list: [String]

    public init(_ list: [String] = []) {
        self.list = list
    }
}

/// Security requirement mapping scheme names to required scopes.
/// Proto: `map<string, StringList> schemes = 1`
public struct SecurityRequirement: Codable, Sendable, Hashable {
    public var schemes: [String: StringList]

    public init(schemes: [String: StringList]) {
        self.schemes = schemes
    }

    /// Convenience initializer accepting plain `[String: [String]]`.
    public init(_ schemes: [String: [String]]) {
        self.schemes = schemes.mapValues { StringList($0) }
    }
}

// MARK: - Scheme Types

/// API key security scheme.
public struct APIKeySecurityScheme: Codable, Sendable, Hashable {
    public var description: String?
    /// Location: "query", "header", or "cookie".
    public var location: String
    /// Parameter name.
    public var name: String

    public init(description: String? = nil, location: String, name: String) {
        self.description = description
        self.location = location
        self.name = name
    }
}

/// HTTP authentication security scheme.
public struct HTTPAuthSecurityScheme: Codable, Sendable, Hashable {
    public var description: String?
    /// e.g. "Bearer".
    public var scheme: String
    /// e.g. "JWT".
    public var bearerFormat: String?

    public init(description: String? = nil, scheme: String, bearerFormat: String? = nil) {
        self.description = description
        self.scheme = scheme
        self.bearerFormat = bearerFormat
    }
}

/// OAuth 2.0 security scheme.
public struct OAuth2SecurityScheme: Codable, Sendable, Hashable {
    public var description: String?
    public var flows: OAuthFlows
    public var oauth2MetadataUrl: String?

    public init(description: String? = nil, flows: OAuthFlows, oauth2MetadataUrl: String? = nil) {
        self.description = description
        self.flows = flows
        self.oauth2MetadataUrl = oauth2MetadataUrl
    }
}

/// OpenID Connect security scheme.
public struct OpenIdConnectSecurityScheme: Codable, Sendable, Hashable {
    public var description: String?
    public var openIdConnectUrl: String

    public init(description: String? = nil, openIdConnectUrl: String) {
        self.description = description
        self.openIdConnectUrl = openIdConnectUrl
    }
}

/// Mutual TLS security scheme.
public struct MutualTlsSecurityScheme: Codable, Sendable, Hashable {
    public var description: String?

    public init(description: String? = nil) {
        self.description = description
    }
}

// MARK: - OAuth Flows

/// OAuth 2.0 flow definitions.
public enum OAuthFlows: Codable, Sendable, Hashable {
    case authorizationCode(AuthorizationCodeOAuthFlow)
    case clientCredentials(ClientCredentialsOAuthFlow)
    case deviceCode(DeviceCodeOAuthFlow)

    private enum CodingKeys: String, CodingKey {
        case authorizationCode
        case clientCredentials
        case deviceCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try container.decodeIfPresent(AuthorizationCodeOAuthFlow.self, forKey: .authorizationCode) {
            self = .authorizationCode(value)
            return
        }
        if let value = try container.decodeIfPresent(ClientCredentialsOAuthFlow.self, forKey: .clientCredentials) {
            self = .clientCredentials(value)
            return
        }
        if let value = try container.decodeIfPresent(DeviceCodeOAuthFlow.self, forKey: .deviceCode) {
            self = .deviceCode(value)
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown OAuth flow type")
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .authorizationCode(let value):
            try container.encode(value, forKey: .authorizationCode)
        case .clientCredentials(let value):
            try container.encode(value, forKey: .clientCredentials)
        case .deviceCode(let value):
            try container.encode(value, forKey: .deviceCode)
        }
    }
}

/// Authorization code OAuth flow.
public struct AuthorizationCodeOAuthFlow: Codable, Sendable, Hashable {
    public var authorizationUrl: String
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]
    public var pkceRequired: Bool?

    public init(authorizationUrl: String, tokenUrl: String, refreshUrl: String? = nil, scopes: [String: String], pkceRequired: Bool? = nil) {
        self.authorizationUrl = authorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
        self.pkceRequired = pkceRequired
    }
}

/// Client credentials OAuth flow.
public struct ClientCredentialsOAuthFlow: Codable, Sendable, Hashable {
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(tokenUrl: String, refreshUrl: String? = nil, scopes: [String: String]) {
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }
}

/// Device code OAuth flow.
public struct DeviceCodeOAuthFlow: Codable, Sendable, Hashable {
    public var deviceAuthorizationUrl: String
    public var tokenUrl: String
    public var refreshUrl: String?
    public var scopes: [String: String]

    public init(deviceAuthorizationUrl: String, tokenUrl: String, refreshUrl: String? = nil, scopes: [String: String]) {
        self.deviceAuthorizationUrl = deviceAuthorizationUrl
        self.tokenUrl = tokenUrl
        self.refreshUrl = refreshUrl
        self.scopes = scopes
    }
}
