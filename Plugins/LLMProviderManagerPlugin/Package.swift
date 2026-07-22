// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMProviderManagerPlugin", targets: ["LLMProviderManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiCoreLLMProvider"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
    ]
)
