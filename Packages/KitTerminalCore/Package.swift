// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitTerminalCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "KitTerminalCore", targets: ["KitTerminalCore"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "KitTerminalCore",
            dependencies: ["SwiftTerm",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "KitTerminalCoreTests",
            dependencies: ["KitTerminalCore"],
            path: "Tests"
        )
    ]
)