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
        .package(path: "../LumiComponentLayout"),
        .package(path: "../LumiComponentGit"),
        .package(path: "../LumiComponentProject"),
        .package(path: "../LumiComponentStorage"),
        .package(path: "../LumiComponentMessage"),
        .package(path: "../LumiComponentAgentTool"),
        .package(path: "../LumiComponentChat"),
        .package(path: "../LumiComponentLLMProvider"),
        .package(path: "../LumiComponentPlugin"),
        .package(path: "../LumiComponentSubAgent"),
        .package(path: "../LumiComponentMenuBar"),
        .package(path: "../LumiComponentOverlay"),
        .package(path: "../LumiComponentPanelChrome"),
    ],
    targets: [
        .target(
            name: "LumiCoreKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
                .product(name: "LumiComponentGit", package: "LumiComponentGit"),
                .product(name: "LumiComponentProject", package: "LumiComponentProject"),
                .product(name: "LumiComponentStorage", package: "LumiComponentStorage"),
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
                .product(name: "LumiComponentAgentTool", package: "LumiComponentAgentTool"),
                .product(name: "LumiComponentChat", package: "LumiComponentChat"),
                .product(name: "LumiComponentLLMProvider", package: "LumiComponentLLMProvider"),
                .product(name: "LumiComponentPlugin", package: "LumiComponentPlugin"),
                .product(name: "LumiComponentSubAgent", package: "LumiComponentSubAgent"),
                .product(name: "LumiComponentMenuBar", package: "LumiComponentMenuBar"),
                .product(name: "LumiComponentOverlay", package: "LumiComponentOverlay"),
                .product(name: "LumiComponentPanelChrome", package: "LumiComponentPanelChrome"),
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
