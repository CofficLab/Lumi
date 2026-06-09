// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolCorePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolCorePlugin",
            targets: ["ToolCorePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/WorkspaceFileKit"),
    ],
    targets: [
        .target(
            name: "ToolCorePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "WorkspaceFileKit", package: "WorkspaceFileKit"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/CommandRiskEvaluator.swift",
                "Sources/Services",
                "Sources/Tools/EditFileTool.swift",
                "Sources/Tools/SharedFileUtils.swift",
                "Sources/Tools/ShellTool.swift",
                "Sources/Tools/ToolCoreToolRisk.swift",
                "Sources/Tools/WriteFileTool.swift",
            ],
            sources: [
                "Sources/ToolCorePlugin.swift",
                "Sources/Tools/ListDirectoryTool.swift",
                "Sources/Tools/ReadFileTool.swift",
                "Sources/Tools/LumiShellTool.swift",
                "Sources/Tools/LumiWriteFileTool.swift",
                "Sources/Tools/LumiEditFileTool.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ToolCorePluginTests",
            dependencies: ["ToolCorePlugin"],
            path: "Tests"
        )
    ]
)
