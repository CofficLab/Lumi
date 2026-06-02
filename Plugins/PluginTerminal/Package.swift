// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginTerminal",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginTerminal",
            targets: ["PluginTerminal"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", .upToNextMajor(from: "1.5.0")),
        .package(path: "../../Packages/TerminalCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginTerminal",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "TerminalCoreKit", package: "TerminalCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginTerminalTests",
            dependencies: ["PluginTerminal"],
            path: "Tests"
        )
    ]
)
