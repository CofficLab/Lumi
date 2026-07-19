// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileLogPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FileLogPlugin",
            targets: ["FileLogPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "FileLogPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "FileLogPluginTests",
            dependencies: ["FileLogPlugin"],
            path: "Tests"
        )
    ]
)
