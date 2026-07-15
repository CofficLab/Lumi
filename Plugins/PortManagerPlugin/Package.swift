// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PortManagerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PortManagerPlugin",
            targets: ["PortManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
    ],
    targets: [
        .target(
            name: "PortManagerPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "PortManagerPluginTests",
            dependencies: ["PortManagerPlugin"],
            path: "Tests"
        )
    ]
)
