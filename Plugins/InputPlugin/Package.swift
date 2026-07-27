// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "InputPlugin", targets: ["InputPlugin"])],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "InputPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        )
    ]
)