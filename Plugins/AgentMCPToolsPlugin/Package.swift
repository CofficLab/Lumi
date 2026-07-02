// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentMCPToolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentMCPToolsPlugin",
            targets: ["AgentMCPToolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", .upToNextMajor(from: "0.10.2")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AgentMCPToolsPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AgentMCPToolsPluginTests",
            dependencies: ["AgentMCPToolsPlugin"],
            path: "Tests"
        )
    ]
)
