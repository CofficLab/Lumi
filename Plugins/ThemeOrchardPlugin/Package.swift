// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThemeOrchardPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ThemeOrchardPlugin",
            targets: ["ThemeOrchardPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ThemeOrchardPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ThemeOrchardPluginTests",
            dependencies: ["ThemeOrchardPlugin"],
            path: "Tests"
        )
    ]
)
