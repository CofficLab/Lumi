// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceInfoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DeviceInfoPlugin",
            targets: ["DeviceInfoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "DeviceInfoPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "DeviceInfoPluginTests",
            dependencies: ["DeviceInfoPlugin"],
            path: "Tests"
        )
    ]
)
