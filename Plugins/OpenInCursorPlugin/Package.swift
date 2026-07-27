// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInCursorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInCursorPlugin",
            targets: ["OpenInCursorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "OpenInCursorPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInCursorPluginTests",
            dependencies: ["OpenInCursorPlugin"],
            path: "Tests"
        )
    ]
)
