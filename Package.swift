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
    ],
    targets: [
        .target(
            name: "A2A",
            path: "Sources/A2A"
        ),
        .testTarget(
            name: "A2ATests",
            dependencies: ["A2A"],
            path: "Tests/A2ATests"
        ),
    ]
)
