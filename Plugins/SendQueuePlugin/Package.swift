// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SendQueuePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SendQueuePlugin", targets: ["SendQueuePlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "SendQueuePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "SendQueuePluginTests",
            dependencies: ["SendQueuePlugin"]
        ),
    ]
)
