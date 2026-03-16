import Testing
import Foundation
@testable import A2A

// URLProtocol subclassing is not supported on Linux's FoundationNetworking,
// so these tests only run on Darwin platforms.
#if !canImport(FoundationNetworking)

@Suite("AgentCardResolver", .serialized)
struct AgentCardResolverTests {

    private func makeCard(name: String = "Test Agent") -> AgentCard {
        AgentCard(
            name: name,
            description: "A test agent",
            supportedInterfaces: [
                AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
            ],
            version: "1.0.0",
            defaultInputModes: ["text/plain"],
            defaultOutputModes: ["text/plain"],
            skills: [
                AgentSkill(id: "test", name: "Test", description: "Test skill", tags: ["test"])
            ]
        )
    }

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test func resolveReturnsCachedCard() async throws {
        let cardData = try JSONEncoder().encode(makeCard())
        MockURLProtocol.reset()
        MockURLProtocol.responseData = cardData
        MockURLProtocol.statusCode = 200

        let session = makeMockSession()
        let resolver = AgentCardResolver(defaultTTL: 300, session: session)
        let url = URL(string: "http://localhost:8080")!

        let resolved1 = try await resolver.resolve(url: url)
        #expect(resolved1.name == "Test Agent")
        #expect(MockURLProtocol.fetchCount == 1)

        // Change mock response
        MockURLProtocol.responseData = try JSONEncoder().encode(makeCard(name: "Updated Agent"))

        // Should return cached
        let resolved2 = try await resolver.resolve(url: url)
        #expect(resolved2.name == "Test Agent")
        #expect(MockURLProtocol.fetchCount == 1)
    }

    @Test func resolveRespectsExpiration() async throws {
        let cardData = try JSONEncoder().encode(makeCard())
        MockURLProtocol.reset()
        MockURLProtocol.responseData = cardData
        MockURLProtocol.statusCode = 200

        let session = makeMockSession()
        let resolver = AgentCardResolver(defaultTTL: 0, session: session)
        let url = URL(string: "http://localhost:8080")!

        let resolved1 = try await resolver.resolve(url: url)
        #expect(resolved1.name == "Test Agent")

        // Update mock
        MockURLProtocol.responseData = try JSONEncoder().encode(makeCard(name: "Updated Agent"))

        // Should fetch again due to expired TTL
        let resolved2 = try await resolver.resolve(url: url)
        #expect(resolved2.name == "Updated Agent")
    }

    @Test func invalidateRemovesCachedCard() async throws {
        let cardData = try JSONEncoder().encode(makeCard())
        MockURLProtocol.reset()
        MockURLProtocol.responseData = cardData
        MockURLProtocol.statusCode = 200

        let session = makeMockSession()
        let resolver = AgentCardResolver(defaultTTL: 300, session: session)
        let url = URL(string: "http://localhost:8080")!

        _ = try await resolver.resolve(url: url)
        #expect(MockURLProtocol.fetchCount == 1)

        _ = try await resolver.resolve(url: url)
        #expect(MockURLProtocol.fetchCount == 1) // Still cached

        await resolver.invalidate(url: url)

        _ = try await resolver.resolve(url: url)
        #expect(MockURLProtocol.fetchCount == 2) // Fetched again after invalidation
    }

    @Test func invalidateAllClearsCache() async throws {
        let cardData = try JSONEncoder().encode(makeCard())
        MockURLProtocol.reset()
        MockURLProtocol.responseData = cardData
        MockURLProtocol.statusCode = 200

        let session = makeMockSession()
        let resolver = AgentCardResolver(defaultTTL: 300, session: session)
        let url1 = URL(string: "http://agent1:8080")!
        let url2 = URL(string: "http://agent2:8080")!

        _ = try await resolver.resolve(url: url1)
        _ = try await resolver.resolve(url: url2)
        #expect(MockURLProtocol.fetchCount == 2)

        await resolver.invalidateAll()

        _ = try await resolver.resolve(url: url1)
        _ = try await resolver.resolve(url: url2)
        #expect(MockURLProtocol.fetchCount == 4)
    }

    @Test func resolvePerURLTTLOverride() async throws {
        let cardData = try JSONEncoder().encode(makeCard())
        MockURLProtocol.reset()
        MockURLProtocol.responseData = cardData
        MockURLProtocol.statusCode = 200

        let session = makeMockSession()
        let resolver = AgentCardResolver(defaultTTL: 300, session: session)
        let url = URL(string: "http://localhost:8080")!

        _ = try await resolver.resolve(url: url, ttl: 0)

        MockURLProtocol.responseData = try JSONEncoder().encode(makeCard(name: "Updated Agent"))

        // Should re-fetch because ttl: 0 stored an immediately-expiring entry
        let resolved = try await resolver.resolve(url: url, ttl: 0)
        #expect(resolved.name == "Updated Agent")
    }

    @Test func resolveThrowsOnHTTPError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.responseData = Data()
        MockURLProtocol.statusCode = 404

        let session = makeMockSession()
        let resolver = AgentCardResolver(session: session)
        let url = URL(string: "http://localhost:8080")!

        await #expect(throws: (any Error).self) {
            _ = try await resolver.resolve(url: url)
        }
    }
}

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseData: Data = Data()
    nonisolated(unsafe) static var statusCode: Int = 200
    nonisolated(unsafe) static var fetchCount: Int = 0

    static func reset() {
        responseData = Data()
        statusCode = 200
        fetchCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.fetchCount += 1
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockURLProtocol.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

#endif
