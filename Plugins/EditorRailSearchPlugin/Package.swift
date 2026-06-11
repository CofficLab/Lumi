// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailSearchPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailSearchPlugin",
            targets: ["EditorRailSearchPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorBottomSearchPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorRailSearchPlugin",
            dependencies: [
                .product(name: "EditorBottomSearchPlugin", package: "EditorBottomSearchPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorRailSearchPluginTests",
            dependencies: ["EditorRailSearchPlugin"],
            path: "Tests"
        )
    ]
)
