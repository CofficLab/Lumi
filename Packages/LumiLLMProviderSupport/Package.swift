// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiLLMProviderSupport",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiLLMProviderSupport",
            targets: ["LumiLLMProviderSupport"]
        ),
    ],
    dependencies: [
        .package(path: "../LLMKit"),
        .package(path: "../LumiCoreLLMProvider"),
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiCoreChat"),
        .package(path: "../HttpKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "LumiLLMProviderSupport",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources"
        )
    ]
)
