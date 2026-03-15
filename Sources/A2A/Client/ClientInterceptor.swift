import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interceptor for A2A client requests.
///
/// Interceptors can modify requests before they are sent (e.g., adding auth tokens),
/// and inspect/modify responses after they are received (e.g., logging, error mapping).
///
/// Example:
/// ```swift
/// struct BearerAuthInterceptor: A2AClientInterceptor {
///     let token: String
///
///     func before(request: inout URLRequest, method: A2AMethod) async throws {
///         request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
///     }
/// }
///
/// struct LoggingInterceptor: A2AClientInterceptor {
///     func before(request: inout URLRequest, method: A2AMethod) async throws {
///         print("-> \(method.rawValue)")
///     }
///
///     func after(response: URLResponse, data: Data, method: A2AMethod) async throws -> Data {
///         print("<- \(method.rawValue): \(data.count) bytes")
///         return data
///     }
/// }
/// ```
public protocol A2AClientInterceptor: Sendable {
    /// Called before a request is sent. Modify the URLRequest to add headers, etc.
    func before(request: inout URLRequest, method: A2AMethod) async throws

    /// Called after a response is received. Can inspect/transform the response data.
    /// Return the (possibly modified) data.
    func after(response: URLResponse, data: Data, method: A2AMethod) async throws -> Data
}

extension A2AClientInterceptor {
    public func before(request: inout URLRequest, method: A2AMethod) async throws {}
    public func after(response: URLResponse, data: Data, method: A2AMethod) async throws -> Data { data }
}

// MARK: - Built-in Interceptors

/// Adds a Bearer token to all requests.
public struct BearerAuthInterceptor: A2AClientInterceptor {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func before(request: inout URLRequest, method: A2AMethod) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

/// Adds an API key header to all requests.
public struct APIKeyInterceptor: A2AClientInterceptor {
    private let headerName: String
    private let apiKey: String

    public init(headerName: String = "X-API-Key", apiKey: String) {
        self.headerName = headerName
        self.apiKey = apiKey
    }

    public func before(request: inout URLRequest, method: A2AMethod) async throws {
        request.setValue(apiKey, forHTTPHeaderField: headerName)
    }
}
