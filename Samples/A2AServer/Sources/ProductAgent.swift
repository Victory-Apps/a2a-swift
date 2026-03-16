import A2A
import Foundation

/// Logs to stderr for immediate Docker output (stdout is buffered in non-interactive mode).
private func trace(_ message: String) {
    let stderr = FileHandle.standardError
    if let data = (message + "\n").data(using: .utf8) {
        stderr.write(data)
    }
}

/// A product catalog agent that answers questions using the catalog data + Ollama.
///
/// Flow:
/// 1. Searches the product catalog for relevant items based on the user's query
/// 2. Injects matching products as context into the Ollama prompt
/// 3. Streams the LLM's response back to the client via A2A
///
/// If Ollama is unavailable, falls back to returning raw search results.
struct ProductAgent: AgentExecutor {
    let catalog: ProductCatalog
    let ollama: OllamaClient?

    init(catalog: ProductCatalog, ollama: OllamaClient? = nil) {
        self.catalog = catalog
        self.ollama = ollama
    }

    func execute(context: RequestContext, updater: TaskUpdater) async throws {
        let query = context.userText
        let history = context.task.history ?? []
        trace("┌─── 📨 SERVER: REQUEST RECEIVED ───────────────")
        trace("│ User query: \"\(query)\"")
        trace("│ Task ID: \(context.task.id)")
        trace("│ Is new task: \(context.isNewTask)")
        trace("│ History messages: \(history.count)")
        trace("└───────────────────────────────────────────────")

        updater.startWork(message: "Searching catalog...")

        // Search the catalog
        let results = catalog.search(query)
        let allProducts = catalog.products
        let productContext = results.isEmpty
            ? ProductCatalog.formatForContext(allProducts)
            : ProductCatalog.formatForContext(results)

        trace("┌─── 🔍 SERVER: CATALOG SEARCH ─────────────────")
        trace("│ Query terms: \"\(query)\"")
        trace("│ Matches: \(results.count) / \(allProducts.count) products")
        if !results.isEmpty {
            trace("│ Found: \(results.map(\.name).joined(separator: ", "))")
        } else {
            trace("│ No matches — sending full catalog as context")
        }
        trace("└───────────────────────────────────────────────")

        let categories = catalog.categories.joined(separator: ", ")

        // If we have Ollama, use LLM to generate a natural response
        if let ollama {
            let systemPrompt = """
            You are a product catalog assistant. You MUST answer questions using ONLY \
            the product data provided below. Do NOT say you don't have access to a catalog. \
            The catalog data is right here in this prompt.

            CATALOG SUMMARY: \(allProducts.count) products across categories: \(categories).

            PRODUCT DATA:
            \(productContext)

            RULES:
            - ALWAYS use the product data above to answer questions
            - Reference specific product names and prices from the data
            - If asked how many products, count the items listed above
            - Be concise and helpful
            """

            let artifactId = UUID().uuidString
            var isFirst = true

            updater.startWork(message: "Generating response...")

            // Build Ollama messages from task history for conversation continuity.
            // Previous user/agent messages give Ollama context for follow-up questions.
            var messages: [OllamaMessage] = [.system(systemPrompt)]

            // Add prior conversation turns (skip the current message — it's last in history)
            let priorMessages = context.isNewTask ? [] : history.dropLast()
            for msg in priorMessages {
                let text = msg.parts.compactMap(\.text).joined()
                guard !text.isEmpty else { continue }
                switch msg.role {
                case .user:
                    messages.append(.user(text))
                case .agent:
                    messages.append(.assistant(text))
                }
            }

            // Add current query
            let augmentedQuery = context.isNewTask
                ? "Using the product catalog data provided above, answer this question: \(query)"
                : query  // Follow-ups don't need the preamble
            messages.append(.user(augmentedQuery))

            trace("┌─── 🤖 SERVER: OLLAMA REQUEST ─────────────────")
            trace("│ Model: \(ollama.model)")
            trace("│ Conversation turns: \(messages.count) (including system)")
            trace("│ User message: \"\(String(augmentedQuery.prefix(100)))\"")
            trace("└───────────────────────────────────────────────")

            let stream = ollama.chatStream(messages: messages, system: systemPrompt)

            do {
                var responseText = ""
                for try await chunk in stream {
                    responseText += chunk
                    updater.streamText(
                        chunk,
                        artifactId: artifactId,
                        name: "response",
                        append: !isFirst,
                        lastChunk: false
                    )
                    isFirst = false
                }
                updater.streamText("", artifactId: artifactId, append: true, lastChunk: true)
                // Store the full response in task history for conversation continuity
                updater.sendMessage(parts: [.text(responseText)])
                trace("┌─── ✅ SERVER: OLLAMA RESPONSE COMPLETE ───────")
                trace("│ Response: \"\(String(responseText.prefix(200)))\"")
                trace("└───────────────────────────────────────────────")
                updater.complete()
            } catch {
                trace("┌─── ❌ SERVER: OLLAMA ERROR ────────────────────")
                trace("│ Error: \(error)")
                trace("└───────────────────────────────────────────────")
                if isFirst {
                    // Ollama failed before any output — fall back to raw results
                    returnRawResults(query: query, results: results, updater: updater)
                } else {
                    updater.streamText(
                        "\n\n[Response interrupted]",
                        artifactId: artifactId,
                        append: true,
                        lastChunk: true
                    )
                    updater.complete()
                }
            }
        } else {
            // No Ollama — return formatted search results directly
            returnRawResults(query: query, results: results, updater: updater)
        }
    }

    private func returnRawResults(query: String, results: [Product], updater: TaskUpdater) {
        let text: String
        if results.isEmpty {
            text = "No products found matching '\(query)'.\n\nAvailable categories: \(catalog.categories.joined(separator: ", "))\n\nTry asking about a specific category or product type."
        } else {
            text = "Found \(results.count) product(s) matching '\(query)':\n\n\(ProductCatalog.formatForContext(results))"
        }

        updater.addArtifact(
            name: "search-results",
            description: "Product search results",
            parts: [.text(text)]
        )
        updater.complete()
    }
}
