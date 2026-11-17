// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitLLM",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "KitLLM", targets: ["KitLLM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKitKeychain.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
    ],
    targets: [
        .target(
            name: "KitLLM",
            dependencies: [
                .product(name: "KitKeychain", package: "LumiKitKeychain"),
                // 工具挂起载荷的契约判据（`ToolSuspensionKind`）。
                //
                // - Note: `KitAgentTool` 只依赖 Foundation 层的 LumiLogging /
                //   LumiLocalization，不反向依赖 KitLLM，因此这里没有循环依赖。
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ],
            path: "Sources/KitLLM"
        ),
        .testTarget(name: "KitLLMTests", dependencies: ["KitLLM"], path: "Tests/KitLLMTests"),
    ]
)
