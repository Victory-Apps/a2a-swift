// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "A2AChatClient",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/Victory-Apps/a2a-swift.git", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "A2AChatClient",
            dependencies: [
                .product(name: "A2A", package: "a2a-swift"),
            ],
            path: "Sources",
            exclude: ["Info.plist"]
        ),
    ]
)
