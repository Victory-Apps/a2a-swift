import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFoundationCompat

/// Lightweight client for Ollama's REST API with true streaming on all platforms.
///
/// Uses AsyncHTTPClient (SwiftNIO-based) for streaming, which works on both macOS and Linux.
struct OllamaClient: Sendable {
    let baseURL: URL
    let model: String

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "qwen3:0.6b"
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    /// Convenience initializer reading from environment variables.
    init(fromEnvironment: Void = ()) {
        let host = ProcessInfo.processInfo.environment["OLLAMA_HOST"] ?? "http://localhost:11434"
        let model = ProcessInfo.processInfo.environment["OLLAMA_MODEL"] ?? "llama3.2"
        self.init(
            baseURL: URL(string: host)!,
            model: model
        )
    }

    // MARK: - Chat

    /// Sends a chat completion and yields text chunks via true streaming.
    func chatStream(
        messages: [OllamaMessage],
        system: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = baseURL.appendingPathComponent("api/chat").absoluteString
                    var body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": messages.map { $0.dictionary }
                    ]
                    if let system {
                        body["system"] = system
                    }

                    let bodyData = try JSONSerialization.data(withJSONObject: body)

                    var request = HTTPClientRequest(url: url)
                    request.method = .POST
                    request.headers.add(name: "Content-Type", value: "application/json")
                    request.body = .bytes(ByteBuffer(data: bodyData))

                    let response = try await HTTPClient.shared.execute(
                        request,
                        timeout: .seconds(120)
                    )

                    guard response.status == .ok else {
                        let responseBody = try await response.body.collect(upTo: 1024 * 1024)
                        let errorText = String(buffer: responseBody)
                        continuation.finish(
                            throwing: OllamaError.httpError(Int(response.status.code), errorText)
                        )
                        return
                    }

                    // Stream the response body line by line
                    var buffer = ""
                    for try await chunk in response.body {
                        guard !Task.isCancelled else { break }

                        let text = String(buffer: chunk)
                        buffer += text

                        // Process complete lines (each line is a JSON object)
                        while let newlineIndex = buffer.firstIndex(of: "\n") {
                            let line = String(buffer[buffer.startIndex..<newlineIndex])
                            buffer = String(buffer[buffer.index(after: newlineIndex)...])

                            guard !line.isEmpty,
                                  let data = line.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: data)
                                      as? [String: Any],
                                  let message = json["message"] as? [String: Any],
                                  let content = message["content"] as? String,
                                  !content.isEmpty
                            else { continue }

                            continuation.yield(content)

                            if let done = json["done"] as? Bool, done {
                                continuation.finish()
                                return
                            }
                        }
                    }

                    // Process any remaining data in the buffer
                    if !buffer.isEmpty,
                       let data = buffer.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data)
                           as? [String: Any],
                       let message = json["message"] as? [String: Any],
                       let content = message["content"] as? String,
                       !content.isEmpty {
                        continuation.yield(content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Models

struct OllamaMessage: Sendable {
    let role: String
    let content: String

    static func user(_ content: String) -> OllamaMessage {
        OllamaMessage(role: "user", content: content)
    }

    static func assistant(_ content: String) -> OllamaMessage {
        OllamaMessage(role: "assistant", content: content)
    }

    static func system(_ content: String) -> OllamaMessage {
        OllamaMessage(role: "system", content: content)
    }

    var dictionary: [String: String] {
        ["role": role, "content": content]
    }
}

enum OllamaError: Error, LocalizedError {
    case httpError(Int, String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            return "Ollama returned HTTP \(code): \(body)"
        case .noResponse:
            return "No response from Ollama"
        }
    }
}
