import Testing
import Foundation
@testable import A2A

@Suite("AgentCard Encoding/Decoding")
struct AgentCardTests {
    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    let decoder = JSONDecoder()

    @Test func agentCardRoundTrip() throws {
        let card = AgentCard(
            name: "Test Agent",
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "https://agent.example.com", protocolBinding: "JSONRPC", protocolVersion: "1.0")
            ],
            provider: AgentProvider(url: "https://example.com", organization: "Test Org"),
            version: "1.0.0",
            capabilities: AgentCapabilities(streaming: true, pushNotifications: false),
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain", "application/json"],
            skills: [
                AgentSkill(
                    id: "translate",
                    name: "Translate",
                    description: "Translates text between languages",
                    tags: ["translation", "language"],
                    examples: ["Translate 'hello' to French"]
                )
            ]
        )

        let data = try encoder.encode(card)
        let decoded = try decoder.decode(AgentCard.self, from: data)
        #expect(decoded.name == "Test Agent")
        #expect(decoded.supportedInterfaces.count == 1)
        #expect(decoded.supportedInterfaces[0].protocolBinding == "JSONRPC")
        #expect(decoded.capabilities.streaming == true)
        #expect(decoded.capabilities.pushNotifications == false)
        #expect(decoded.skills.count == 1)
        #expect(decoded.skills[0].id == "translate")
        #expect(decoded.provider?.organization == "Test Org")
    }

    @Test func securitySchemeAPIKey() throws {
        let scheme = SecurityScheme.apiKey(APIKeySecurityScheme(
            description: "API key auth",
            location: "header",
            name: "X-API-Key"
        ))
        let data = try encoder.encode(scheme)
        let decoded = try decoder.decode(SecurityScheme.self, from: data)
        if case .apiKey(let apiKey) = decoded {
            #expect(apiKey.location == "header")
            #expect(apiKey.name == "X-API-Key")
        } else {
            Issue.record("Expected .apiKey")
        }
    }

    @Test func securitySchemeHTTPAuth() throws {
        let scheme = SecurityScheme.httpAuth(HTTPAuthSecurityScheme(
            scheme: "Bearer",
            bearerFormat: "JWT"
        ))
        let data = try encoder.encode(scheme)
        let decoded = try decoder.decode(SecurityScheme.self, from: data)
        if case .httpAuth(let auth) = decoded {
            #expect(auth.scheme == "Bearer")
            #expect(auth.bearerFormat == "JWT")
        } else {
            Issue.record("Expected .httpAuth")
        }
    }

    @Test func securitySchemeOAuth2() throws {
        let scheme = SecurityScheme.oauth2(OAuth2SecurityScheme(
            flows: .authorizationCode(AuthorizationCodeOAuthFlow(
                authorizationUrl: "https://auth.example.com/authorize",
                tokenUrl: "https://auth.example.com/token",
                scopes: ["read": "Read access", "write": "Write access"],
                pkceRequired: true
            ))
        ))
        let data = try encoder.encode(scheme)
        let decoded = try decoder.decode(SecurityScheme.self, from: data)
        if case .oauth2(let oauth) = decoded {
            if case .authorizationCode(let flow) = oauth.flows {
                #expect(flow.authorizationUrl == "https://auth.example.com/authorize")
                #expect(flow.pkceRequired == true)
                #expect(flow.scopes.count == 2)
            } else {
                Issue.record("Expected .authorizationCode")
            }
        } else {
            Issue.record("Expected .oauth2")
        }
    }

    @Test func securityRequirement() throws {
        let req = SecurityRequirement(schemes: ["bearer": StringList(["read", "write"])])
        let data = try encoder.encode(req)
        let json = String(data: data, encoding: .utf8)!
        // Verify proto-compliant format: {"schemes":{"bearer":{"list":["read","write"]}}}
        #expect(json.contains("\"schemes\""))
        #expect(json.contains("\"list\""))
        let decoded = try decoder.decode(SecurityRequirement.self, from: data)
        #expect(decoded.schemes["bearer"]?.list == ["read", "write"])
    }

    @Test func securityRequirementConvenienceInit() throws {
        let req = SecurityRequirement(["bearer": ["read", "write"]])
        #expect(req.schemes["bearer"]?.list == ["read", "write"])
    }
}
