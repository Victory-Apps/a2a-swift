import Foundation

/// In-memory product catalog loaded from a JSON file at startup.
///
/// Edit `products.json` to customize the catalog — no code changes needed.
struct ProductCatalog: Sendable {
    let products: [Product]

    /// Loads the catalog from a JSON file path.
    /// Falls back to bundled demo data if the file doesn't exist or fails to parse.
    static func load(from path: String = "products.json") -> ProductCatalog {
        let url = URL(fileURLWithPath: path)
        do {
            let data = try Data(contentsOf: url)
            let products = try JSONDecoder().decode([Product].self, from: data)
            print("Loaded \(products.count) products from \(path)")
            return ProductCatalog(products: products)
        } catch {
            print("Could not load \(path): \(error.localizedDescription)")
            print("Using built-in demo catalog")
            return .demo
        }
    }

    /// Searches products by keyword across name, category, and description.
    func search(_ query: String) -> [Product] {
        let terms = query.lowercased().split(separator: " ")
        return products.filter { product in
            let searchable = "\(product.name) \(product.category) \(product.description) \(product.tags.joined(separator: " "))".lowercased()
            return terms.contains { searchable.contains($0) }
        }
    }

    /// Filters products by category.
    func byCategory(_ category: String) -> [Product] {
        products.filter { $0.category.lowercased() == category.lowercased() }
    }

    /// Filters products under a price.
    func under(price: Double) -> [Product] {
        products.filter { $0.price <= price }
    }

    /// Returns all unique categories.
    var categories: [String] {
        Array(Set(products.map(\.category))).sorted()
    }

    /// Formats products as context for the LLM.
    static func formatForContext(_ products: [Product]) -> String {
        if products.isEmpty {
            return "No matching products found."
        }
        return products.map { product in
            """
            - \(product.name) ($\(String(format: "%.2f", product.price)))
              Category: \(product.category)
              \(product.description)
              In stock: \(product.inStock ? "Yes" : "No")
            """
        }.joined(separator: "\n")
    }
}

struct Product: Sendable, Codable {
    let id: String
    let name: String
    let price: Double
    let category: String
    let description: String
    let tags: [String]
    let inStock: Bool
}

// MARK: - Built-in Demo Data (fallback)

extension ProductCatalog {
    static let demo = ProductCatalog(products: [
        Product(id: "laptop-1", name: "SwiftBook Pro 14\"", price: 1299.99, category: "Laptops",
                description: "Powerful laptop with M4 chip, 16GB RAM, 512GB SSD. Perfect for development and creative work.",
                tags: ["apple", "professional", "development"], inStock: true),
        Product(id: "laptop-2", name: "SwiftBook Air 13\"", price: 899.99, category: "Laptops",
                description: "Ultra-thin and light laptop with M3 chip, 8GB RAM, 256GB SSD. Great for everyday use.",
                tags: ["apple", "portable", "lightweight"], inStock: true),
        Product(id: "laptop-3", name: "CodeStation 16\"", price: 1799.99, category: "Laptops",
                description: "High-performance workstation laptop with M4 Pro chip, 32GB RAM, 1TB SSD. Built for heavy workloads.",
                tags: ["professional", "workstation", "development"], inStock: false),
        Product(id: "laptop-4", name: "StudentBook SE", price: 599.99, category: "Laptops",
                description: "Affordable laptop with M2 chip, 8GB RAM, 256GB SSD. Ideal for students and light work.",
                tags: ["budget", "student", "portable"], inStock: true),
        Product(id: "acc-1", name: "MagSafe Charger Pro", price: 49.99, category: "Accessories",
                description: "Fast wireless charger compatible with all MagSafe devices. 15W charging.",
                tags: ["charger", "wireless", "magsafe"], inStock: true),
        Product(id: "acc-2", name: "Thunderbolt Dock Ultra", price: 299.99, category: "Accessories",
                description: "12-port Thunderbolt 4 dock with dual 6K display support, 96W charging, and SD card reader.",
                tags: ["dock", "thunderbolt", "professional"], inStock: true),
        Product(id: "acc-3", name: "Precision Mouse", price: 79.99, category: "Accessories",
                description: "Ergonomic wireless mouse with multi-touch surface and USB-C charging.",
                tags: ["mouse", "wireless", "ergonomic"], inStock: true),
        Product(id: "acc-4", name: "Mechanical Keyboard Pro", price: 199.99, category: "Accessories",
                description: "Low-profile mechanical keyboard with backlit keys, Touch ID, and USB-C connectivity.",
                tags: ["keyboard", "mechanical", "professional"], inStock: false),
        Product(id: "audio-1", name: "StudioPods Pro", price: 249.99, category: "Audio",
                description: "Premium noise-cancelling earbuds with spatial audio, adaptive EQ, and 6-hour battery life.",
                tags: ["earbuds", "noise-cancelling", "wireless"], inStock: true),
        Product(id: "audio-2", name: "OverEar Max", price: 549.99, category: "Audio",
                description: "High-fidelity over-ear headphones with active noise cancellation, 20-hour battery.",
                tags: ["headphones", "noise-cancelling", "premium"], inStock: true),
        Product(id: "audio-3", name: "HomeSphere Mini", price: 99.99, category: "Audio",
                description: "Compact smart speaker with room-filling sound, voice assistant, and multi-room audio support.",
                tags: ["speaker", "smart", "home"], inStock: true),
        Product(id: "display-1", name: "UltraWide 5K Display", price: 1599.99, category: "Displays",
                description: "34-inch 5K ultrawide display with P3 wide color, 600 nits brightness, and Thunderbolt connectivity.",
                tags: ["monitor", "ultrawide", "5k", "professional"], inStock: true),
        Product(id: "display-2", name: "Studio Display 27\"", price: 1299.99, category: "Displays",
                description: "27-inch 5K Retina display with 12MP camera, studio-quality mics, and six-speaker sound system.",
                tags: ["monitor", "retina", "5k", "camera"], inStock: false),
    ])
}
