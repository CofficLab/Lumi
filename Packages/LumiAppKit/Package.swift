// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumiAppKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LumiAppKit",
            targets: ["LumiAppKit"]
        )
    ],
    dependencies: [
        // 在此声明 LumiApp 层依赖的子 package（待补充）
    ],
    targets: [
        .target(
            name: "LumiAppKit",
            dependencies: [],
            path: "Sources/LumiAppKit"
        ),
        .testTarget(
            name: "LumiAppKitTests",
            dependencies: ["LumiAppKit"],
            path: "Tests/LumiAppKitTests"
        )
    ]
)