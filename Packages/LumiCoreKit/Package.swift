// swift-tools-version: 6.0
import PackageDescription

/// LumiCoreKit — 插件系统的核心协议与类型
///
/// 将 SuperPlugin、SuperLLMProvider、SuperSendMiddleware 等协议及其依赖的
/// 值类型（ChatMessage、StreamChunk 等）集中到独立 Package 中，
/// 使插件可以作为独立 Swift Package 存在并拥有自己的单元测试。
let package = Package(
    name: "LumiCoreKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreKit",
            targets: ["LumiCoreKit"]
        )
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../AgentToolKit"),
        .package(path: "../HttpKit"),
        .package(path: "../LLMKit"),
        .package(path: "../LLMProviderKit"),
        .package(path: "../LumiUI"),
        // 注意：不直接依赖 EditorService，通过 EditorExtensionRegistry 协议解耦
    ],
    targets: [
        .target(
            name: "LumiCoreKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/LumiCoreKit"
        ),
        .testTarget(
            name: "LumiCoreKitTests",
            dependencies: ["LumiCoreKit"],
            path: "Tests/LumiCoreKitTests"
        )
    ]
)
