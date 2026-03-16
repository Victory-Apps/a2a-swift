import A2AVapor
import Vapor

// MARK: - Product Catalog

let catalogPath = ProcessInfo.processInfo.environment["CATALOG_PATH"] ?? "products.json"
let catalog = ProductCatalog.load(from: catalogPath)

// MARK: - Agent Selection

// With Ollama: ProductAgent uses catalog + LLM for natural language answers
// Without Ollama: ProductAgent returns raw search results (still useful)
// Set AGENT_MODE=echo to use the simple echo agent instead

let agentMode = ProcessInfo.processInfo.environment["AGENT_MODE"] ?? "product"
let useOllama = ProcessInfo.processInfo.environment["OLLAMA_HOST"] != nil

let executor: any AgentExecutor
let agentCard: AgentCard

switch agentMode {
case "echo":
    executor = EchoAgent()
    agentCard = AgentCard(
        name: "Echo Agent",
        description: "A streaming echo agent that repeats your messages back word-by-word. Built with a2a-swift + Vapor.",
        supportedInterfaces: [
            AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
        ],
        provider: AgentProvider(url: "https://github.com/Victory-Apps/a2a-swift", organization: "a2a-swift"),
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: true, pushNotifications: false),
        defaultInputModes: ["text/plain"],
        defaultOutputModes: ["text/plain"],
        skills: [
            AgentSkill(id: "echo", name: "Echo", description: "Echoes back whatever you send, streaming word-by-word",
                       tags: ["echo", "test", "demo"], examples: ["Hello, world!"])
        ]
    )
    print("Starting Echo Agent")

case "llm":
    executor = LLMAgent()
    agentCard = AgentCard(
        name: "LLM Agent",
        description: "A general-purpose AI assistant powered by Ollama. Built with a2a-swift + Vapor.",
        supportedInterfaces: [
            AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
        ],
        provider: AgentProvider(url: "https://github.com/Victory-Apps/a2a-swift", organization: "a2a-swift"),
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: true, pushNotifications: false),
        defaultInputModes: ["text/plain"],
        defaultOutputModes: ["text/plain"],
        skills: [
            AgentSkill(id: "chat", name: "Chat",
                       description: "General-purpose AI assistant. Ask questions, get explanations, brainstorm ideas.",
                       tags: ["chat", "ai", "llm"], examples: ["Explain quantum computing", "Write a haiku about Swift"])
        ]
    )
    let ollama = OllamaClient(fromEnvironment: ())
    print("Starting LLM Agent with Ollama at \(ollama.baseURL) using model '\(ollama.model)'")

default: // "product"
    let ollama: OllamaClient? = useOllama ? OllamaClient(fromEnvironment: ()) : nil
    executor = ProductAgent(catalog: catalog, ollama: ollama)
    let categoryList = catalog.categories.joined(separator: ", ")
    let productCount = catalog.products.count
    let priceRange = "from $\(catalog.products.map(\.price).min().map { String(format: "%.2f", $0) } ?? "0") to $\(catalog.products.map(\.price).max().map { String(format: "%.2f", $0) } ?? "0")"

    agentCard = AgentCard(
        name: "Tech Store Product Catalog",
        description: """
        A product catalog assistant with \(productCount) products across \(categoryList). \
        Prices range \(priceRange). \
        Ask about products, compare items, check availability, or browse by category. \
        Powered by \(useOllama ? "Ollama + " : "")a2a-swift.
        """,
        supportedInterfaces: [
            AgentInterface(url: "http://localhost:8080", protocolVersion: "1.0")
        ],
        provider: AgentProvider(url: "https://github.com/Victory-Apps/a2a-swift", organization: "a2a-swift"),
        version: "1.0.0",
        capabilities: AgentCapabilities(streaming: useOllama, pushNotifications: false),
        defaultInputModes: ["text/plain"],
        defaultOutputModes: ["text/plain"],
        skills: [
            AgentSkill(id: "product-search", name: "Product Search",
                       description: """
                       Search and browse a catalog of \(productCount) tech products. \
                       Categories: \(categoryList). \
                       You can ask about specific products, filter by price or category, \
                       check stock availability, and compare items side by side.
                       """,
                       tags: ["products", "catalog", "search", "shopping"],
                       examples: [
                           "What laptops do you have?",
                           "Show me accessories under $100",
                           "Do you have any noise-cancelling headphones?",
                           "Compare the SwiftBook Pro and Air",
                           "What's out of stock?",
                           "How many products do you carry?"
                       ])
        ]
    )
    if let ollama {
        print("Starting Product Catalog Agent (\(catalog.products.count) products) with Ollama at \(ollama.baseURL)")
    } else {
        print("Starting Product Catalog Agent (\(catalog.products.count) products) without LLM (set OLLAMA_HOST to enable)")
    }
}

// MARK: - A2A Setup

let handler = DefaultRequestHandler(executor: executor, card: agentCard)

// MARK: - Vapor App

let app = try await Application.make()
try configure(app)

app.mountA2A(handler: handler)

try await app.execute()
