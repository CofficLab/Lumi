// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreAgentTool",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiCoreAgentTool", targets: ["LumiCoreAgentTool"])
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
    ],
    targets: [
        .target(
            name: "LumiCoreAgentTool",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources"
        )
    ]
)
