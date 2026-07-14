// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSampleDecorationPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSampleDecorationPlugin",
            targets: ["EditorSampleDecorationPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),    ],
    targets: [
        .target(
            name: "EditorSampleDecorationPlugin",
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
            name: "EditorSampleDecorationPluginTests",
            dependencies: ["EditorSampleDecorationPlugin"],
            path: "Tests"
        )
    ]
)
