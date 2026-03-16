# Examples

Single-file code examples showing how to use the [a2a-swift](https://github.com/Victory-Apps/a2a-swift) SDK. These are reference snippets — copy the patterns into your own project.

> **Looking for complete, runnable apps?** See [`Samples/`](../Samples/) for standalone Swift packages you can build and run.

## Files

| File | Description |
|------|-------------|
| [**EchoAgent.swift**](EchoAgent.swift) | Agent implementation patterns — echo, streaming translation, and multi-turn conversation agents using `AgentExecutor` + `DefaultRequestHandler` |
| [**A2AClientApp.swift**](A2AClientApp.swift) | SwiftUI client that connects to any A2A agent with streaming responses, agent card discovery, and multi-turn support |
| [**OnDeviceLLMAgent.swift**](OnDeviceLLMAgent.swift) | Apple Intelligence agent using Foundation Models for on-device inference with token-by-token streaming |

## EchoAgent.swift

Demonstrates three `AgentExecutor` patterns:

- **EchoAgent** — simplest possible agent, echoes user input as an artifact
- **StreamingTranslationAgent** — streams output word-by-word using `updater.streamText()`
- **ConversationalAgent** — multi-turn flow using `updater.requireInput()` to keep tasks alive

Also shows how to wire up `DefaultRequestHandler` → `A2ARouter` and integrate with Vapor or Hummingbird.

## A2AClientApp.swift

A complete SwiftUI chat client in a single file:

- Connect to any A2A agent by URL
- Fetch and display agent card (name, skills)
- Send messages with streaming (`sendStreamingMessage`) or synchronous (`sendMessage`) modes
- Multi-turn conversations via `taskId` tracking
- Chat bubble UI with user/agent/system message styles

## OnDeviceLLMAgent.swift

An A2A agent powered by Apple's on-device language model:

- Uses `FoundationModels` framework (macOS 26+ / iOS 26+)
- Streams responses token-by-token via `LanguageModelSession.streamResponse()`
- Handles delta extraction from cumulative Foundation Models output
- Includes a bonus structured output example using `@Generable`

Requires Apple Silicon with Apple Intelligence enabled.

## Usage

These files aren't standalone packages — they show patterns to integrate into your own app. For runnable examples, see:

- [`Samples/A2AServer/`](../Samples/A2AServer/) — full Vapor server with Docker
- [`Samples/A2AChatClient/`](../Samples/A2AChatClient/) — full macOS SwiftUI client
