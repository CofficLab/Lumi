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
        )
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../LLMKit"),
        .package(path: "../LLMProviderKit"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LumiLLMProviderSupport",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "LumiLLMProviderSupportTests",
            dependencies: ["LumiLLMProviderSupport"],
            path: "Tests"
        )
    ]
)
