// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorNavigationContextMenuPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorNavigationContextMenuPlugin",
            targets: ["EditorNavigationContextMenuPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),    ],
    targets: [
        .target(
            name: "EditorNavigationContextMenuPlugin",
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
            name: "EditorNavigationContextMenuPluginTests",
            dependencies: ["EditorNavigationContextMenuPlugin"],
            path: "Tests"
        )
    ]
)