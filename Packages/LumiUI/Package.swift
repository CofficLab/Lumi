// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiUI",
            targets: ["LumiUI"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit")
    ],
    targets: [
        .target(
            name: "LumiUI",
            dependencies: ["AgentToolKit"],
            path: "Sources/LumiUI"
        ),
        .testTarget(
            name: "LumiUITests",
            dependencies: ["LumiUI"],
            path: "Tests/LumiUITests"
        )
    ]
)
