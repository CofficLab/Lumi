// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorLSPContextCommandsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorLSPContextCommandsPlugin",
            targets: ["EditorLSPContextCommandsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorCodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorLSPContextCommandsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorCodeEditTextView", package: "EditorCodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorLSPContextCommandsPluginTests",
            dependencies: ["EditorLSPContextCommandsPlugin"],
            path: "Tests"
        )
    ]
)
