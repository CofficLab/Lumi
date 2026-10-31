// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitLLM",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitLLM", targets: ["KitLLM"]),
    ],
    dependencies: [
        .package(path: "../KitKeychain"),
        .package(path: "../KitAgentTool"),
    ],
    targets: [
        .target(
            name: "KitLLM",
            dependencies: [
                .product(name: "KitKeychain", package: "KitKeychain"),
                // 工具挂起载荷的契约判据（`ToolSuspensionKind`）。
                //
                // - Note: `KitAgentTool` 只依赖 Foundation 层的 LumiLogging /
                //   LumiLocalization，不反向依赖 KitLLM，因此这里没有循环依赖。
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Sources/KitLLM"
        ),
        .testTarget(name: "KitLLMTests", dependencies: ["KitLLM"], path: "Tests/KitLLMTests"),
    ]
)
