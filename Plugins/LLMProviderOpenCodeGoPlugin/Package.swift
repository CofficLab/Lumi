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
    ],
    targets: [
        .target(name: "LLMProviderOpenCodeGoPlugin", dependencies: [
            .product(name: "KernelLumi", package: "KernelLumi"),
            .product(name: "LLMKit", package: "LLMKit"),
        ], path: "Sources"),
        .testTarget(name: "LLMProviderOpenCodeGoPluginTests", dependencies: ["LLMProviderOpenCodeGoPlugin"], path: "Tests"),
    ]
)
