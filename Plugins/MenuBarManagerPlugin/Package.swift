// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MenuBarManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "MenuBarManagerPlugin", targets: ["MenuBarManagerPlugin"])],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../AppUpdatePlugin")
    ],
    targets: [
        .target(
            name: "MenuBarManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "AppUpdatePlugin", package: "AppUpdatePlugin")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        )
        ),
        .testTarget(
            name: "MenuBarManagerPluginTests",
            dependencies: [.target(name: "MenuBarManagerPlugin")],
            path: "Tests"
        )
    ]
)