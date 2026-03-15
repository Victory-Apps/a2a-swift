// Example: On-Device LLM Agent using Apple Foundation Models + A2A
//
// This agent uses Apple's on-device language model (available on iOS 26+, macOS 26+)
// to respond to messages. It supports streaming, multi-turn conversations, and
// structured output — all exposed as a standard A2A agent that any client can talk to.
//
// Requirements:
// - iOS 26+ / macOS 26+ with Apple Intelligence enabled
// - Apple Silicon (M1+) or A17 Pro+
//
// To run: integrate with Vapor, Hummingbird, or any HTTP server.

#if canImport(FoundationModels)
import A2A
import Foundation
import FoundationModels

// MARK: - 1. Agent Executor — On-Device LLM

struct OnDeviceLLMAgent: AgentExecutor {
    let systemPrompt: String

    init(systemPrompt: String = "You are a helpful, concise assistant.") {
        self.systemPrompt = systemPrompt
    }

    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        // Check model availability
        guard SystemLanguageModel.default.isAvailable else {
            updater.fail(message: "Apple Intelligence is not available on this device. Ensure Apple Intelligence is enabled in Settings and the on-device model is downloaded.")
            return
        }

        updater.startWork(message: "Thinking...")

        // Create a session with system instructions
        let session = LanguageModelSession(instructions: systemPrompt)

        // Stream the response token by token
        let artifactId = UUID().uuidString
        let stream = session.streamResponse(to: context.userText)

        var lastContent = ""
        var isFirst = true

        for try await partial in stream {
            let fullText = partial.content
            // Foundation Models returns cumulative text, so extract the delta
            let delta = String(fullText.dropFirst(lastContent.count))
            guard !delta.isEmpty else { continue }
            lastContent = fullText

            updater.streamText(
                delta,
                artifactId: artifactId,
                name: "response",
                append: !isFirst,
                lastChunk: false
            )
            isFirst = false
        }

        // Signal the final chunk
        updater.streamText("", artifactId: artifactId, append: true, lastChunk: true)
        updater.complete()
    }
}

// MARK: - 2. Agent Card

let onDeviceLLMAgentCard = AgentCard(
    name: "Apple Intelligence Agent",
    description: "An A2A agent powered by Apple's on-device language model. Runs entirely on-device with no cloud dependency — your data never leaves the device.",
    supportedInterfaces: [
        AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
    ],
    provider: AgentProvider(url: "https://github.com/Victory-Apps/a2a-swift", organization: "a2a-swift"),
    version: "1.0.0",
    capabilities: AgentCapabilities(streaming: true, pushNotifications: false),
    defaultInputModes: ["text/plain"],
    defaultOutputModes: ["text/plain"],
    skills: [
        AgentSkill(
            id: "chat",
            name: "Chat",
            description: "General-purpose conversational AI powered by Apple Intelligence. Answers questions, writes text, summarizes content, and more — all on-device.",
            tags: ["chat", "general", "on-device", "apple-intelligence"],
            examples: [
                "Explain quantum computing in simple terms",
                "Write a haiku about Swift programming",
                "Summarize the key points of this article",
                "Help me draft a professional email"
            ]
        )
    ]
)

// MARK: - 3. Wire it up

let onDeviceLLMHandler = DefaultRequestHandler(
    executor: OnDeviceLLMAgent(),
    card: onDeviceLLMAgentCard
)

let onDeviceLLMRouter = A2ARouter(handler: onDeviceLLMHandler)

// MARK: - 4. Structured Output Agent (bonus)

// Apple's Foundation Models supports structured output via @Generable.
// Here's an agent that returns structured data through A2A:

/*
@Generable
struct AnalysisResult {
    var summary: String
    var sentiment: String
    var keyTopics: [String]
    var confidence: Double
}

struct StructuredAnalysisAgent: AgentExecutor {
    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        guard SystemLanguageModel.default.isAvailable else {
            updater.fail(message: "Apple Intelligence not available")
            return
        }

        updater.startWork(message: "Analyzing...")

        let session = LanguageModelSession(
            instructions: "Analyze the following text and provide structured output."
        )

        let response = try await session.respond(
            to: context.userText,
            generating: AnalysisResult.self
        )

        let result = response.content

        // Return structured data as a JSON artifact
        updater.addArtifact(
            name: "analysis",
            parts: [
                .data(.object([
                    "summary": .string(result.summary),
                    "sentiment": .string(result.sentiment),
                    "keyTopics": .array(result.keyTopics.map { .string($0) }),
                    "confidence": .double(result.confidence)
                ]))
            ]
        )
        updater.complete(message: "Analysis complete")
    }
}
*/

#endif
