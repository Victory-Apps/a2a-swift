import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Resolves and caches agent cards from remote URLs with TTL-based expiration.
///
/// `AgentCardResolver` is useful in multi-agent scenarios where you need to discover
/// and cache agent capabilities without repeatedly fetching agent cards.
///
/// ```swift
/// let resolver = AgentCardResolver()
///
/// // First call fetches from the network
/// let card = try await resolver.resolve(url: agentURL)
///
/// // Subsequent calls return the cached card until TTL expires
/// let cached = try await resolver.resolve(url: agentURL)
///
/// // Force a fresh fetch
/// await resolver.invalidate(url: agentURL)
/// let fresh = try await resolver.resolve(url: agentURL)
/// ```
public actor AgentCardResolver {
    private struct CachedCard {
        let card: AgentCard
        let fetchedAt: Date
        let ttl: TimeInterval
    }

    private var cache: [URL: CachedCard] = [:]
    private let defaultTTL: TimeInterval
    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Creates an agent card resolver.
    ///
    /// - Parameters:
    ///   - defaultTTL: Default time-to-live for cached cards in seconds. Defaults to 300 (5 minutes).
    ///   - session: The URL session to use for fetching. Defaults to `.shared`.
    public init(defaultTTL: TimeInterval = 300, session: URLSession = .shared) {
        self.defaultTTL = defaultTTL
        self.session = session
    }

    /// Resolves an agent card from the given base URL.
    ///
    /// Returns a cached card if one exists and hasn't expired, otherwise fetches
    /// from `<url>/.well-known/agent-card.json`.
    ///
    /// - Parameters:
    ///   - url: The base URL of the agent.
    ///   - ttl: Optional TTL override for this specific resolution.
    /// - Returns: The resolved ``AgentCard``.
    public func resolve(url: URL, ttl: TimeInterval? = nil) async throws -> AgentCard {
        let effectiveTTL = ttl ?? defaultTTL

        if let cached = cache[url], !isExpired(cached) {
            return cached.card
        }

        let card = try await fetch(baseURL: url)
        cache[url] = CachedCard(card: card, fetchedAt: Date(), ttl: effectiveTTL)
        return card
    }

    /// Removes a cached card for the given URL.
    public func invalidate(url: URL) {
        cache.removeValue(forKey: url)
    }

    /// Removes all cached cards.
    public func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Private

    private func isExpired(_ cached: CachedCard) -> Bool {
        Date().timeIntervalSince(cached.fetchedAt) >= cached.ttl
    }

    private func fetch(baseURL: URL) async throws -> AgentCard {
        let url = baseURL.appendingPathComponent(".well-known/agent-card.json")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw A2AError(code: .internalError, message: "Invalid HTTP response")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw A2AError(
                code: .internalError,
                message: "Agent card fetch failed with status \(httpResponse.statusCode)"
            )
        }

        return try decoder.decode(AgentCard.self, from: data)
    }
}
