// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreKit",
            targets: ["LumiCoreKit"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../HttpKit"),
        .package(path: "../LLMKit"),
        .package(path: "../LumiCoreLayout"),
        .package(path: "../LumiCoreGit"),
        .package(path: "../LumiCoreProject"),
        .package(path: "../LumiCoreStorage"),
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiCoreChat"),
        .package(path: "../LumiCoreLLMProvider"),
        .package(path: "../LumiCorePlugin"),
        .package(path: "../LumiCoreSubAgent"),
        .package(path: "../LumiCoreMenuBar"),
        .package(path: "../LumiCoreOverlay"),
        .package(path: "../LumiCorePanelChrome"),
    ],
    targets: [
        .target(
            name: "LumiCoreKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
                .product(name: "LumiCoreGit", package: "LumiCoreGit"),
                .product(name: "LumiCoreProject", package: "LumiCoreProject"),
                .product(name: "LumiCoreStorage", package: "LumiCoreStorage"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
                .product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider"),
                .product(name: "LumiCorePlugin", package: "LumiCorePlugin"),
                .product(name: "LumiCoreSubAgent", package: "LumiCoreSubAgent"),
                .product(name: "LumiCoreMenuBar", package: "LumiCoreMenuBar"),
                .product(name: "LumiCoreOverlay", package: "LumiCoreOverlay"),
                .product(name: "LumiCorePanelChrome", package: "LumiCorePanelChrome"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "LumiCoreKitTests",
            dependencies: ["LumiCoreKit"]
        )
    ]
)
