// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NetworkManagerPlugin",
            targets: ["NetworkManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "NetworkManagerPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "NetworkManagerPluginTests",
            dependencies: ["NetworkManagerPlugin"],
            path: "Tests"
        )
    ]
)
