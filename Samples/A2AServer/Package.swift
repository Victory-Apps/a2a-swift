// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "A2AServer",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/Victory-Apps/a2a-swift.git", from: "0.4.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.20.0"),
    ],
    targets: [
        .executableTarget(
            name: "A2AServer",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "A2AVapor", package: "a2a-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Sources"
        ),
    ]
)
