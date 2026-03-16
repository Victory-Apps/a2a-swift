import Foundation

/// Configuration for SSE streaming reconnection behavior.
///
/// When a streaming connection drops unexpectedly, the client can automatically
/// retry with exponential backoff. Use ``default`` for sensible defaults or
/// ``disabled`` to opt out of reconnection.
///
/// ```swift
/// // Default reconnection (3 retries with exponential backoff)
/// let client = A2AClient(baseURL: url)
///
/// // Custom configuration
/// let client = A2AClient(
///     baseURL: url,
///     sseConfiguration: SSEConfiguration(maxRetries: 5, initialRetryInterval: 2.0)
/// )
///
/// // Disable reconnection
/// let client = A2AClient(baseURL: url, sseConfiguration: .disabled)
/// ```
public struct SSEConfiguration: Sendable, Equatable {
    /// Maximum number of reconnection attempts before giving up.
    public var maxRetries: Int

    /// Initial delay between reconnection attempts in seconds.
    public var initialRetryInterval: TimeInterval

    /// Maximum delay between reconnection attempts in seconds.
    public var maxRetryInterval: TimeInterval

    /// Multiplier applied to the retry interval after each failed attempt.
    public var backoffMultiplier: Double

    /// Fraction of the retry interval to use as random jitter (0.0–1.0).
    public var jitterFraction: Double

    public init(
        maxRetries: Int = 3,
        initialRetryInterval: TimeInterval = 1.0,
        maxRetryInterval: TimeInterval = 30.0,
        backoffMultiplier: Double = 2.0,
        jitterFraction: Double = 0.1
    ) {
        self.maxRetries = maxRetries
        self.initialRetryInterval = initialRetryInterval
        self.maxRetryInterval = maxRetryInterval
        self.backoffMultiplier = backoffMultiplier
        self.jitterFraction = jitterFraction
    }

    /// Default configuration with 3 retries and exponential backoff.
    public static let `default` = SSEConfiguration()

    /// Disabled reconnection — errors are thrown immediately.
    public static let disabled = SSEConfiguration(maxRetries: 0)

    /// Calculates the delay for a given retry attempt, incorporating backoff and jitter.
    internal func delay(forAttempt attempt: Int) -> TimeInterval {
        let base = initialRetryInterval * pow(backoffMultiplier, Double(attempt))
        let clamped = min(base, maxRetryInterval)
        let jitter = clamped * jitterFraction * Double.random(in: -1...1)
        return max(0, clamped + jitter)
    }
}
