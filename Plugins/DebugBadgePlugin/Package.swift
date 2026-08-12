// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DebugBadgePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "DebugBadgePlugin", targets: ["DebugBadgePlugin"])],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit")
    ],
    targets: [
        .target(
            name: "DebugBadgePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "DebugBadgePluginTests",
            dependencies: [.target(name: "DebugBadgePlugin")],
            path: "Tests"
        )
    ]
)
