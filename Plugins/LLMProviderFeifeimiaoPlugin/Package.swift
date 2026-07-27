// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderFeifeimiaoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderFeifeimiaoPlugin",
            targets: ["LLMProviderFeifeimiaoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderFeifeimiaoPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderFeifeimiaoPluginTests",
            dependencies: ["LLMProviderFeifeimiaoPlugin"],
            path: "Tests"
        )
    ]
)
