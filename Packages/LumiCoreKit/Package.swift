// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreKit",
            targets: ["LumiCoreKit"]
        ),
    ],
    dependencies: [
        .package(path: "../SuperLogKit"),
        .package(path: "../LumiLocalizationKit"),
        .package(path: "../KeychainKit"),
        .package(path: "../LumiComponentLayout"),
        .package(path: "../LumiComponentGit"),
        .package(path: "../LumiComponentProject"),
        .package(path: "../LumiComponentStorage"),
        .package(path: "../LumiComponentMessage"),
    ],
    targets: [
        .target(
            name: "LumiCoreKit",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
                .product(name: "LumiComponentLayout", package: "LumiComponentLayout"),
                .product(name: "LumiComponentGit", package: "LumiComponentGit"),
                .product(name: "LumiComponentProject", package: "LumiComponentProject"),
                .product(name: "LumiComponentStorage", package: "LumiComponentStorage"),
                .product(name: "LumiComponentMessage", package: "LumiComponentMessage"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "LumiCoreKitTests",
            dependencies: ["LumiCoreKit"]
        )
    ]
)
