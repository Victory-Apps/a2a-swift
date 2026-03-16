# A2AServer

A Dockerized A2A agent server built with **Vapor** and **Ollama**. Ships with a product catalog agent that answers natural language questions about a tech store inventory, with full conversation memory via A2A task continuations.

## Features

- **Product catalog agent** — searches a JSON product database and generates natural language responses via Ollama
- **SSE streaming** — token-by-token response streaming over Server-Sent Events
- **Conversation continuity** — maintains chat history across requests using A2A `taskId`
- **Agent card discovery** — standard `.well-known/agent-card.json` endpoint
- **Multiple agent modes** — product (default), echo, or general LLM
- **Docker Compose** — one-command setup with Ollama + model auto-pull

## Prerequisites

You only need **one** of these:

| Option | What to install | Best for |
|--------|----------------|----------|
| **Docker** (recommended) | [Docker Desktop](https://www.docker.com/products/docker-desktop/) | One-command setup, no local dependencies |
| **Local** | Swift 6.0+ ([Xcode](https://developer.apple.com/xcode/) or [swift.org](https://www.swift.org/install/)) + [Ollama](https://ollama.com) (optional) | Faster iteration, no container overhead |

## Quick Start (Docker)

```bash
docker compose up --build
```

This starts three services:
1. **ollama** — Ollama inference server
2. **ollama-init** — pulls the `qwen3:0.6b` model (one-time)
3. **a2a-server** — the A2A agent on port `8080`

First run takes a few minutes to pull the model. Subsequent starts are instant.

## Quick Start (Local)

**With Ollama** (natural language responses):

```bash
# Install and start Ollama (if not already running)
brew install ollama
ollama serve &
ollama pull qwen3:0.6b

# Run the server
OLLAMA_HOST=http://localhost:11434 swift run
```

**Without Ollama** (returns structured search results, zero setup):

```bash
swift run
```

> Without Ollama the agent still works — it returns formatted catalog search results instead of LLM-generated prose.

## API Endpoints

### Agent Card Discovery

```bash
curl http://localhost:8080/.well-known/agent-card.json | jq .
```

Returns the agent's capabilities, skills, and metadata.

### Send Message (JSON-RPC)

```bash
curl -X POST http://localhost:8080 \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "What laptops do you have?"}]
      }
    }
  }'
```

### Send Streaming Message (SSE)

```bash
curl -X POST http://localhost:8080 \
  -H 'Content-Type: application/json' \
  -N \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "message/sendStream",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Compare your most expensive and cheapest products"}]
      }
    }
  }'
```

### Multi-turn Conversation

Include the `taskId` from a previous response to continue the conversation:

```bash
curl -X POST http://localhost:8080 \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "message/sendStream",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Which one has better reviews?"}],
        "taskId": "TASK_ID_FROM_PREVIOUS_RESPONSE"
      }
    }
  }'
```

## Agent Modes

Set the `AGENT_MODE` environment variable to switch agents:

| Mode | Description |
|------|-------------|
| `product` (default) | Product catalog + Ollama for natural language answers |
| `echo` | Simple streaming echo agent (no LLM required) |
| `llm` | General-purpose Ollama chat agent |

```bash
# Run as echo agent (no Ollama needed)
AGENT_MODE=echo swift run

# Run as general LLM agent
AGENT_MODE=llm OLLAMA_HOST=http://localhost:11434 swift run
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AGENT_MODE` | `product` | Agent type: `product`, `echo`, or `llm` |
| `OLLAMA_HOST` | _(none)_ | Ollama server URL (e.g., `http://localhost:11434`) |
| `OLLAMA_MODEL` | `qwen3:0.6b` | Ollama model name |
| `CATALOG_PATH` | `products.json` | Path to product catalog JSON file |
| `LOG_LEVEL` | `info` | Vapor log level |

## Project Structure

```
A2AServer/
├── Package.swift           # SPM manifest (Vapor + a2a-swift)
├── Dockerfile              # Multi-stage build (swift:6.0 → ubuntu:24.04)
├── docker-compose.yml      # Server + Ollama stack
├── .dockerignore
├── products.json           # Product catalog data (20 tech products)
└── Sources/
    ├── main.swift           # Vapor app setup + A2A route registration
    ├── configure.swift      # Vapor configuration (host, port)
    ├── ProductAgent.swift   # Catalog search + Ollama LLM agent
    ├── ProductCatalog.swift # JSON catalog loading and search
    ├── OllamaClient.swift   # Ollama HTTP client with streaming
    ├── EchoAgent.swift      # Simple streaming echo agent
    └── LLMAgent.swift       # General-purpose Ollama agent
```

## How It Works

### Product Agent Flow

```
User: "What laptops do you have?"
  │
  ├─ 1. Search catalog for matching products
  │     → SwiftBook Pro 16", SwiftBook Air 13"
  │
  ├─ 2. Build Ollama prompt with:
  │     • System prompt (catalog rules + all product data)
  │     • Prior conversation turns (from task history)
  │     • Current query
  │
  ├─ 3. Stream Ollama response via SSE
  │     → Token-by-token artifact updates
  │
  └─ 4. Store response in task history
        → Enables follow-up questions
```

### Vapor ↔ A2A Integration

The server uses three a2a-swift components:

```swift
// 1. Your agent logic
let executor = ProductAgent(catalog: catalog, ollama: ollama)

// 2. SDK handles task lifecycle, events, streaming
let handler = DefaultRequestHandler(executor: executor, card: agentCard)

// 3. Router dispatches JSON-RPC methods
let router = A2ARouter(handler: handler)

// 4. Register with Vapor
app.get(".well-known", "agent-card.json") { ... }
app.post { ... router.route(body: body) ... }
```

## Customization

### Using Your Own Product Data

Replace `products.json` with your own catalog. The expected format:

```json
[
  {
    "id": "unique-id",
    "name": "Product Name",
    "description": "Product description",
    "price": 999.99,
    "category": "Category",
    "inStock": true,
    "specs": {
      "key": "value"
    }
  }
]
```

### Using a Different LLM

Change the Ollama model via environment variable:

```bash
OLLAMA_MODEL=llama3.2:3b docker compose up --build
```

Or modify `docker-compose.yml` to pull a different model in the init container.
