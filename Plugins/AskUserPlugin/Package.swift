// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AskUserPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AskUserPlugin", targets: ["AskUserPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "AskUserPlugin",
            dependencies: [
                "AgentToolKit",
                "SuperLogKit",
                "LumiCoreKit",
                "LumiUI",
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "AskUserPluginTests",
            dependencies: ["AskUserPlugin", "AgentToolKit", "LumiCoreKit"],
            path: "Tests"
        ),
    ]
)
