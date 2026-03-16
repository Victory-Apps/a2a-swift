import A2A
import Vapor

extension RoutesBuilder {
    /// Mounts A2A agent endpoints on this routes builder.
    ///
    /// This registers two routes:
    /// - `GET /.well-known/agent-card.json` — Agent card discovery
    /// - `POST <path>` — JSON-RPC endpoint (handles both regular and streaming requests)
    ///
    /// ```swift
    /// let handler = DefaultRequestHandler(executor: myAgent, card: agentCard)
    /// app.mountA2A(handler: handler)
    /// ```
    ///
    /// - Parameters:
    ///   - handler: An ``A2AAgentHandler`` that processes A2A requests.
    ///   - path: The path for the JSON-RPC endpoint. Defaults to `""` (root).
    @discardableResult
    public func mountA2A(
        handler: any A2AAgentHandler,
        path: String = ""
    ) -> A2ARouteCollection {
        let collection = A2ARouteCollection(handler: handler, path: path)
        collection.register(on: self)
        return collection
    }

    /// Mounts A2A agent endpoints using an existing ``A2ARouter``.
    ///
    /// Use this overload when you need to share a router instance or have already
    /// configured one.
    ///
    /// - Parameters:
    ///   - router: A pre-configured ``A2ARouter``.
    ///   - path: The path for the JSON-RPC endpoint. Defaults to `""` (root).
    @discardableResult
    public func mountA2A(
        router: A2ARouter,
        path: String = ""
    ) -> A2ARouteCollection {
        let collection = A2ARouteCollection(router: router, path: path)
        collection.register(on: self)
        return collection
    }
}

/// Encapsulates the A2A route registration for a Vapor application.
public struct A2ARouteCollection: Sendable {
    private let router: A2ARouter
    private let path: String

    /// Creates a route collection from an ``A2AAgentHandler``.
    public init(handler: any A2AAgentHandler, path: String = "") {
        self.router = A2ARouter(handler: handler)
        self.path = path
    }

    /// Creates a route collection from an existing ``A2ARouter``.
    public init(router: A2ARouter, path: String = "") {
        self.router = router
        self.path = path
    }

    /// Registers the A2A routes on the given routes builder.
    public func register(on routes: RoutesBuilder) {
        let router = self.router

        // Agent card discovery endpoint
        routes.get(".well-known", "agent-card.json") { req async throws -> Response in
            let data = try await router.handleAgentCardRequest()
            return Response(
                status: .ok,
                headers: ["content-type": "application/json"],
                body: .init(data: data)
            )
        }

        // JSON-RPC endpoint
        let pathComponents: [PathComponent] = path.isEmpty ? [] : path.split(separator: "/").map { PathComponent(stringLiteral: String($0)) }

        routes.on(.POST, pathComponents) { req async throws -> Response in
            let body = Data(buffer: req.body.data ?? ByteBuffer())
            let result = try await router.route(body: body)

            switch result {
            case .response(let data):
                return Response(
                    status: .ok,
                    headers: ["content-type": "application/json"],
                    body: .init(data: data)
                )

            case .stream(let stream):
                let responseBody = Response.Body(asyncStream: { writer in
                    for try await chunk in stream {
                        try await writer.write(.buffer(ByteBuffer(data: chunk)))
                    }
                })
                return Response(
                    status: .ok,
                    headers: [
                        "content-type": "text/event-stream",
                        "cache-control": "no-cache",
                        "connection": "keep-alive",
                    ],
                    body: responseBody
                )

            case .agentCard(let data):
                return Response(
                    status: .ok,
                    headers: ["content-type": "application/json"],
                    body: .init(data: data)
                )
            }
        }
    }
}
