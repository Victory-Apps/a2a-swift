// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "A2A",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "A2A",
            targets: ["A2A"]
        ),
        .library(
            name: "A2AVapor",
            targets: ["A2AVapor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
    ],
    targets: [
        .target(
            name: "A2A",
            path: "Sources/A2A"
        ),
        .target(
            name: "A2AVapor",
            dependencies: [
                "A2A",
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/A2AVapor"
        ),
        .testTarget(
            name: "A2ATests",
            dependencies: ["A2A"],
            path: "Tests/A2ATests"
        ),
        .testTarget(
            name: "A2AVaporTests",
            dependencies: [
                "A2AVapor",
                .product(name: "VaporTesting", package: "vapor"),
            ],
            path: "Tests/A2AVaporTests"
        ),
    ]
)
