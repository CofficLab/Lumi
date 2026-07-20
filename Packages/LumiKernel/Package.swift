// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiKernel",
            targets: ["LumiKernel"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../LumiCoreAgentTool"),
        .package(path: "../LumiCoreLayout"),
        .package(path: "../LumiCoreLLMProvider"),
        .package(path: "../LumiCoreMenuBar"),
        .package(path: "../LumiCoreMessage"),
        .package(path: "../LumiCoreOverlay"),
        .package(path: "../LumiCorePanelChrome"),
        .package(path: "../LumiCoreProject"),
        .package(path: "../LumiCoreStorage"),
        .package(path: "../LumiCoreSubAgent"),
    ],
    targets: [
        .target(
            name: "LumiKernel",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiCoreAgentTool", package: "LumiCoreAgentTool"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
                .product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider"),
                .product(name: "LumiCoreMenuBar", package: "LumiCoreMenuBar"),
                .product(name: "LumiCoreMessage", package: "LumiCoreMessage"),
                .product(name: "LumiCoreOverlay", package: "LumiCoreOverlay"),
                .product(name: "LumiCorePanelChrome", package: "LumiCorePanelChrome"),
                .product(name: "LumiCoreProject", package: "LumiCoreProject"),
                .product(name: "LumiCoreStorage", package: "LumiCoreStorage"),
                .product(name: "LumiCoreSubAgent", package: "LumiCoreSubAgent"),
            ],
            path: "Sources/LumiKernel",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LumiKernelTests",
            dependencies: ["LumiKernel"]
        )
    ]
)
