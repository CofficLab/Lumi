// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatScreenshotPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatScreenshotPlugin",
            targets: ["ChatScreenshotPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ChatScreenshotPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ChatScreenshotPlugin",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ChatScreenshotPluginTests",
            dependencies: [
                "ChatScreenshotPlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Tests/ChatScreenshotPlugin"
        ),
    ]
)