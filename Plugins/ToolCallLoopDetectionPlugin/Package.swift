// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolCallLoopDetectionPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ToolCallLoopDetectionPlugin",
            targets: ["ToolCallLoopDetectionPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ToolCallLoopDetectionPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ToolCallLoopDetectionPluginTests",
            dependencies: ["ToolCallLoopDetectionPlugin"],
            path: "Tests"
        )
    ]
)
