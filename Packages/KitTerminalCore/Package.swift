// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitTerminalCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "KitTerminalCore", targets: ["KitTerminalCore"])],
    dependencies: [
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "KitTerminalCore",
            dependencies: ["SwiftTerm",
                .product(name: "KitLocalization", package: "KitLocalization"),
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