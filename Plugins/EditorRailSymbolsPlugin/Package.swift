// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailSymbolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailSymbolsPlugin",
            targets: ["EditorRailSymbolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorBottomSymbolsPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorRailSymbolsPlugin",
            dependencies: [
                .product(name: "EditorBottomSymbolsPlugin", package: "EditorBottomSymbolsPlugin"),
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
            name: "EditorRailSymbolsPluginTests",
            dependencies: ["EditorRailSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
