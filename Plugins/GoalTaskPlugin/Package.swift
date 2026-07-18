// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GoalTaskPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GoalTaskPlugin", targets: ["GoalTaskPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "GoalTaskPlugin",
            dependencies: ["LumiCoreKit", "SuperLogKit", "LumiUI"],
            path: "Sources"
        ),
        .testTarget(
            name: "GoalTaskPluginTests",
            dependencies: ["GoalTaskPlugin"],
            path: "Tests"
        )
    ]
)