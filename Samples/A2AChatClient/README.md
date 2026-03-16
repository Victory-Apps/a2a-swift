# A2AChatClient

A native macOS chat client that connects to any A2A-compatible agent. Features multi-agent connectivity, streaming responses, conversation history, and optional Apple Intelligence on-device orchestration for automatic agent routing.

## Features

- **Multi-agent support** — connect to multiple A2A agents simultaneously
- **Agent discovery** — fetches and displays agent cards with capabilities and skills
- **SSE streaming** — real-time token-by-token response rendering
- **Conversation continuity** — maintains chat history across messages via A2A `taskId`
- **Apple Intelligence routing** — on-device Foundation Models decides which agent to delegate to (macOS 26+)
- **Manual agent selection** — dropdown picker when Foundation Models is unavailable
- **Native SwiftUI** — sidebar navigation, chat bubbles, connection management

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| macOS | 15.0+ | 26.0+ for Apple Intelligence routing |
| [Xcode](https://developer.apple.com/xcode/) | 26+ | From Mac App Store |
| An A2A agent to connect to | — | Use the [A2AServer sample](../A2AServer/) or any A2A-compatible agent |

> **Apple Intelligence is optional.** The app works without it — it auto-delegates when one agent is connected, or shows a manual picker for multiple agents.

## Quick Start

```bash
# Open in Xcode
open Package.swift

# Build & Run (⌘R)
```

Then in the app:
1. Click **"Connect an Agent"** in the sidebar
2. Enter the agent URL (e.g., `http://localhost:8080`)
3. Click **Connect** — the agent card appears with name, description, and skills
4. Start chatting!

### Run with the A2AServer sample

```bash
# Terminal 1: Start the server
cd ../A2AServer
docker compose up --build
# Wait for "Starting Product Catalog Agent" in the logs

# Terminal 2: Open the client
cd ../A2AChatClient
open Package.swift
# Build & Run (⌘R), then connect to http://localhost:8080
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     A2AChatClient                       │
│                                                         │
│  ┌──────────┐    ┌──────────────────┐    ┌───────────┐  │
│  │  Views    │───►│  ChatViewModel   │───►│ Orchestr. │  │
│  │          │    │  (@Observable)    │    │  Service  │  │
│  │ Sidebar  │    │                  │    │           │  │
│  │ ChatView │◄───│ messages[]       │    │ FM / auto │  │
│  │ Bubbles  │    │ connectedAgents[]│    │ / manual  │  │
│  └──────────┘    └────────┬─────────┘    └─────┬─────┘  │
│                           │                     │        │
│                    ┌──────▼─────────────────────▼──┐     │
│                    │        A2AService              │     │
│                    │                                │     │
│                    │  A2AClient per agent           │     │
│                    │  taskId tracking               │     │
│                    │  SSE stream → AsyncStream      │     │
│                    └────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
                              │
                     A2A Protocol (HTTP)
                              │
                    ┌─────────▼─────────┐
                    │   Any A2A Agent    │
                    │  (Swift, Python,   │
                    │   JS, Java, .NET)  │
                    └───────────────────┘
```

### Message Flow

```
User types message
  → ChatViewModel.sendMessage()
    → OrchestratorService.process(message, agents)
      ├── Foundation Models available?
      │   YES → FM decides: answer directly OR delegate
      │   NO  → Manual agent selection / auto-delegate
      └── A2AService.sendMessage(to: agentURL)
          → A2AClient.sendStreamingMessage()
            → SSE events → AsyncThrowingStream
              → ChatViewModel updates messages[]
                → SwiftUI re-renders
```

## Project Structure

```
A2AChatClient/
├── Package.swift
└── Sources/
    ├── A2AChatClientApp.swift          # @main entry point
    ├── Info.plist                       # Bundle metadata
    ├── Models/
    │   ├── ChatMessage.swift            # UI message model (user/agent/system)
    │   └── AgentConnection.swift        # Connected agent with card metadata
    ├── Services/
    │   ├── A2AService.swift             # A2AClient wrapper + taskId tracking
    │   └── OrchestratorService.swift    # FM orchestration + delegation logic
    ├── ViewModels/
    │   └── ChatViewModel.swift          # Central @Observable state management
    └── Views/
        ├── ContentView.swift            # NavigationSplitView layout
        ├── ChatView.swift               # Message list + input bar
        ├── MessageBubble.swift          # Styled chat bubble (user/agent/system)
        ├── AgentSidebar.swift           # Connected agents list + empty state
        └── ConnectionSheet.swift        # Agent URL input + card preview
```

## Key Components

### A2AService

Manages connections to remote A2A agents:

- **Connect/disconnect** — creates `A2AClient` instances, fetches agent cards
- **Task ID tracking** — stores `activeTaskIds` per agent URL for conversation continuity
- **Stream mapping** — converts `StreamResponse` SSE events into simplified `StreamEvent` values
- **Terminal state detection** — closes SSE streams when task reaches completed/failed/canceled state (avoids hanging on HTTP keep-alive)
- **Duplicate suppression** — skips `.message` events that repeat already-streamed artifact content

### OrchestratorService

Routes user messages to the right handler:

| Scenario | Behavior |
|----------|----------|
| Agent explicitly selected | Direct delegation |
| Foundation Models available | On-device LLM decides: answer or delegate |
| Single agent connected | Auto-delegate |
| Multiple agents, no FM | Error: prompt user to select |
| No agents | Error: prompt user to connect |

When using Foundation Models, the system prompt includes all connected agents' names, descriptions, and skills. The FM responds with `DELEGATE: <url>` to route, or answers directly.

### ChatViewModel

`@MainActor @Observable` class managing all UI state:

- `messages: [ChatMessage]` — chat history
- `connectedAgents: [AgentConnection]` — active agent connections
- `sendMessage()` — creates user bubble, placeholder agent bubble, streams response
- `connectToAgent(url:)` / `disconnect()` — agent lifecycle
- `clearHistory()` — resets messages and conversation task IDs

## Connecting to Any A2A Agent

The client works with any A2A-compatible agent, not just the sample server:

```
# Python A2A agent
http://localhost:5000

# Node.js A2A agent
http://localhost:3000

# Another Swift A2A agent
http://localhost:8080

# Remote agent
https://my-agent.example.com
```

The only requirement is that the agent serves:
- `GET /.well-known/agent-card.json` — agent card
- `POST /` — JSON-RPC endpoint (SendMessage or SendStreamingMessage)
