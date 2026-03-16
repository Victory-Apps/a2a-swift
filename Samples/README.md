# Sample Apps

Complete, runnable sample applications demonstrating the [a2a-swift](https://github.com/Victory-Apps/a2a-swift) SDK in real-world scenarios. Each sample is a standalone Swift package that you can build and run independently.

> **Looking for quick code snippets?** Check out [`Examples/`](../Examples/) for single-file reference implementations of agents and clients.

## Apps

| Sample | Description | Stack |
|--------|-------------|-------|
| [**A2AServer**](A2AServer/) | Dockerized product catalog agent with Ollama LLM | Vapor · Docker · Ollama |
| [**A2AChatClient**](A2AChatClient/) | macOS chat client with multi-agent support | SwiftUI · Foundation Models |

## Prerequisites

Before running the samples, make sure you have the following installed:

| Tool | Required for | Install |
|------|-------------|---------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | A2AServer | `brew install --cask docker` |
| [Xcode 26+](https://developer.apple.com/xcode/) | A2AChatClient | Mac App Store |
| Swift 6.0+ | Both (local builds) | Included with Xcode |

> **No Docker?** You can also run the server locally with `swift run` — see [A2AServer README](A2AServer/) for details.

## Quick Start

Run both apps end-to-end in under 5 minutes:

### 1. Start the server

```bash
cd Samples/A2AServer
docker compose up --build
```

First run pulls the Ollama image and `qwen3:0.6b` model (~500MB). Wait until you see:

```
a2a-server-1  | Starting Product Catalog Agent (20 products) with Ollama at http://ollama:11434
```

### 2. Verify the server is running

```bash
# In a new terminal
curl http://localhost:8080/.well-known/agent-card.json | jq .name
# → "Tech Store Product Catalog"
```

### 3. Run the client

```bash
cd Samples/A2AChatClient
open Package.swift
# Xcode opens → Build & Run (⌘R)
```

### 4. Connect and chat

1. In the app sidebar, click **"Connect an Agent"**
2. Enter `http://localhost:8080`
3. Click **Connect** — you'll see the agent's name and skills
4. Try: *"What laptops do you have?"*, then follow up with *"Which one is cheaper?"*

### No Docker? Run the server locally

```bash
# Option A: With Ollama (natural language responses)
brew install ollama
ollama serve &
ollama pull qwen3:0.6b
cd Samples/A2AServer
OLLAMA_HOST=http://localhost:11434 swift run

# Option B: Without Ollama (returns raw search results, no setup needed)
cd Samples/A2AServer
swift run
```

## Architecture

```
┌──────────────────────┐         A2A Protocol          ┌──────────────────────┐
│   A2AChatClient      │ ◄──── (JSON-RPC + SSE) ────► │   A2AServer          │
│                      │                               │                      │
│  SwiftUI + FM        │  1. Agent card discovery       │  Vapor + Ollama      │
│  orchestration       │  2. SendMessage (streaming)    │  product catalog     │
│                      │  3. Task continuations          │  conversation memory │
└──────────────────────┘                               └──────────────────────┘
```

Both apps use the **a2a-swift** SDK (`A2A` package) — the server uses `AgentExecutor`, `DefaultRequestHandler`, and `A2ARouter`; the client uses `A2AClient` for discovery and streaming communication.
