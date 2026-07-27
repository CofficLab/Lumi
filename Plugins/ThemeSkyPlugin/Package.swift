// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeSkyPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeSkyPlugin",
            targets: ["ThemeSkyPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ThemeSkyPlugin",
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
            name: "ThemeSkyPluginTests",
            dependencies: ["ThemeSkyPlugin"],
            path: "Tests"
        )
    ]
)
