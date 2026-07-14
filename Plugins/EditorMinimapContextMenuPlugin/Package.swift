// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorMinimapContextMenuPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorMinimapContextMenuPlugin",
            targets: ["EditorMinimapContextMenuPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),    ],
    targets: [
        .target(
            name: "EditorMinimapContextMenuPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorMinimapContextMenuPluginTests",
            dependencies: ["EditorMinimapContextMenuPlugin"],
            path: "Tests"
        )
    ]
)
