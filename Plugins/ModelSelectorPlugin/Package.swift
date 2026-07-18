// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelSelectorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ModelSelectorPlugin",
            targets: ["ModelSelectorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ModelSelectorPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ModelSelectorPluginTests",
            dependencies: [
                "ModelSelectorPlugin",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
