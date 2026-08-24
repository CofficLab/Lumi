// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTurnRunner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AgentTurnRunnerPlugin", targets: ["AgentTurnRunnerPlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../AgentToolKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "AgentTurnRunnerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/AgentTurnRunnerPlugin",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "AgentTurnRunnerPluginTests",
            dependencies: ["AgentTurnRunnerPlugin"]
        ),
    ]
)
