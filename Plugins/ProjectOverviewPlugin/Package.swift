// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectOverviewPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectOverviewPlugin",
            targets: ["ProjectOverviewPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/ShellKit"),
    ],
    targets: [
        .target(
            name: "ProjectOverviewPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ShellKit", package: "ShellKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectOverviewPluginTests",
            dependencies: ["ProjectOverviewPlugin"],
            path: "Tests"
        )
    ]
)
