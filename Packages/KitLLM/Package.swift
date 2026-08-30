// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitLLM",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitLLM", targets: ["KitLLM"]),
    ],
    dependencies: [
        .package(path: "../KitKeychain"),
    ],
    targets: [
        .target(
            name: "KitLLM",
            dependencies: [
                .product(name: "KitKeychain", package: "KitKeychain"),
            ],
            path: "Sources/KitLLM"
        ),
        .testTarget(name: "KitLLMTests", dependencies: ["KitLLM"], path: "Tests/KitLLMTests"),
    ]
)
