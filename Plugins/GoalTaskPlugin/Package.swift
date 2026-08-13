// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoalTaskPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GoalTaskPlugin", targets: ["GoalTaskPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "GoalTaskPlugin",
            dependencies: [
                "KernelLumi",
                "SuperLogKit",
                "LumiUI",
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "GoalTaskPluginTests",
            dependencies: ["GoalTaskPlugin"],
            path: "Tests"
        )
    ]
)