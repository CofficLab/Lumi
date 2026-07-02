// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelPreferencePlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ModelPreferencePlugin",
            targets: ["ModelPreferencePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ModelPreferencePlugin",
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
            name: "ModelPreferencePluginTests",
            dependencies: ["ModelPreferencePlugin"],
            path: "Tests"
        )
    ]
)
