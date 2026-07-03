// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RAGKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RAGKit",
            targets: ["RAGKit"]
        ),
    ],
    targets: [
        .target(
            name: "RAGKit",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "RAGKitTests",
            dependencies: ["RAGKit"],
            path: "Tests"
        ),
    ]
)
