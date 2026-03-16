import Foundation

extension Message {
    /// Creates a fixture `Message` with sensible defaults for testing.
    ///
    /// If `parts` is provided, it takes precedence over `text`.
    public static func fixture(
        messageId: String = UUID().uuidString,
        contextId: String? = nil,
        taskId: String? = nil,
        role: Role = .user,
        text: String = "Hello",
        parts: [Part]? = nil
    ) -> Message {
        Message(
            messageId: messageId,
            contextId: contextId,
            taskId: taskId,
            role: role,
            parts: parts ?? [.text(text)]
        )
    }
}

extension SendMessageRequest {
    /// Creates a fixture `SendMessageRequest` with sensible defaults for testing.
    public static func fixture(
        message: Message = .fixture(),
        configuration: SendMessageConfiguration? = nil
    ) -> SendMessageRequest {
        SendMessageRequest(
            message: message,
            configuration: configuration
        )
    }
}

extension RequestContext {
    /// Creates a fixture `RequestContext` with sensible defaults for testing.
    public static func fixture(
        task: A2ATask = .fixture(),
        userMessage: Message = .fixture(),
        request: SendMessageRequest = .fixture(),
        isNewTask: Bool = true
    ) -> RequestContext {
        RequestContext(
            task: task,
            userMessage: userMessage,
            request: request,
            isNewTask: isNewTask
        )
    }
}
