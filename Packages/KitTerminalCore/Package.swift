// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitTerminalCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "KitTerminalCore", targets: ["KitTerminalCore"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        // 上限锁定在 1.99.0 之前：SwiftTerm 的 v1.99.0 实际是 2.0 预发布，
        // 移除了本包依赖的 getTerminal()，放开上限会解析到不兼容版本。
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", "1.20.0" ..< "1.99.0")
    ],
    targets: [
        .target(
            name: "KitTerminalCore",
            dependencies: ["SwiftTerm",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitTerminalCore",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "KitTerminalCoreTests",
            dependencies: ["KitTerminalCore"],
            path: "Tests"
        )
    ]
)