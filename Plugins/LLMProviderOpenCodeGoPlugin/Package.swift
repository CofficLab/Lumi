// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMProviderOpenCodeGoPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "LLMProviderOpenCodeGoPlugin", targets: ["LLMProviderOpenCodeGoPlugin"])],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/HttpKit"),
    ],
    targets: [
        .target(name: "LLMProviderOpenCodeGoPlugin", dependencies: [
            .product(name: "KernelLumi", package: "KernelLumi"),
            .product(name: "LLMKit", package: "LLMKit"),
            .product(name: "HttpKit", package: "HttpKit"),
        ], path: "Sources"),
        .testTarget(name: "LLMProviderOpenCodeGoPluginTests", dependencies: [
            "LLMProviderOpenCodeGoPlugin",
            .product(name: "LLMKit", package: "LLMKit"),
            .product(name: "HttpKit", package: "HttpKit"),
        ], path: "Tests"),
    ]
)
