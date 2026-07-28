// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentTurnRunnerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentTurnRunnerPlugin", targets: ["AgentTurnRunnerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "AgentTurnRunnerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/AgentTurnRunnerPlugin",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
    ]
)
