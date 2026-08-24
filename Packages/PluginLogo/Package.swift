// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "LogoPlugin",
            targets: ["LogoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "LogoPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources/LogoPlugin",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        )
    ]
)
