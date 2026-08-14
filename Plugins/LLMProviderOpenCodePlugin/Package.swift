// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMProviderOpenCodePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "LLMProviderOpenCodePlugin", targets: ["LLMProviderOpenCodePlugin"])],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/HttpKit"),
    ],
    targets: [
        .target(name: "LLMProviderOpenCodePlugin", dependencies: [
            .product(name: "KernelLumi", package: "KernelLumi"),
            .product(name: "LLMKit", package: "LLMKit"),
            .product(name: "HttpKit", package: "HttpKit"),
        ], path: "Sources"),
        .testTarget(name: "LLMProviderOpenCodePluginTests", dependencies: [
            "LLMProviderOpenCodePlugin",
            .product(name: "LLMKit", package: "LLMKit"),
            .product(name: "HttpKit", package: "HttpKit"),
        ], path: "Tests"),
    ]
)
