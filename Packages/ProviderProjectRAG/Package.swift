// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProviderProjectRAG",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "ProviderProjectRAG", targets: ["ProviderProjectRAG"]),
    ],
    targets: [
        .target(name: "ProviderProjectRAG"),
        .testTarget(
            name: "ProviderProjectRAGTests",
            dependencies: ["ProviderProjectRAG"]
        ),
    ]
)
