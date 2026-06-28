// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DownloadPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DownloadPlugin",
            targets: ["DownloadPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/DownloadKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "DownloadPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "DownloadKit", package: "DownloadKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "DownloadPluginTests",
            dependencies: ["DownloadPlugin"]
        )
    ]
)
