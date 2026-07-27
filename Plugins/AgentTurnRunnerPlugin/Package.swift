// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentTurnRunnerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentTurnRunnerPlugin", targets: ["AgentTurnRunnerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "AgentTurnRunnerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/AgentTurnRunnerPlugin"
        ),
    ]
)
