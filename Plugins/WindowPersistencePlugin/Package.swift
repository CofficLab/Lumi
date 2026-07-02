// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindowPersistencePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "WindowPersistencePlugin",
            targets: ["WindowPersistencePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "WindowPersistencePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "WindowPersistencePluginTests",
            dependencies: ["WindowPersistencePlugin"],
            path: "Tests"
        )
    ]
)
