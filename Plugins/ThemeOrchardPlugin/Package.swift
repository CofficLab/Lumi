// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeOrchardPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeOrchardPlugin",
            targets: ["ThemeOrchardPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeOrchardPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeOrchardPluginTests",
            dependencies: ["ThemeOrchardPlugin"],
            path: "Tests"
        )
    ]
)
