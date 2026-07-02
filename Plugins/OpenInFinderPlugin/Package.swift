// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInFinderPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInFinderPlugin",
            targets: ["OpenInFinderPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "OpenInFinderPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInFinderPluginTests",
            dependencies: ["OpenInFinderPlugin"],
            path: "Tests"
        )
    ]
)
