// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMenuBarManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MenuBarManagerPlugin", targets: ["MenuBarManagerPlugin"])],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit")
    ],
    targets: [
        .target(
            name: "MenuBarManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "MenuBarManagerPluginTests",
            dependencies: [.target(name: "MenuBarManagerPlugin")],
            path: "Tests"
        )
    ]
)