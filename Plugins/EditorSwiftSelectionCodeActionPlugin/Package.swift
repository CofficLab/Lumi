// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftSelectionCodeActionPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftSelectionCodeActionPlugin",
            targets: ["EditorSwiftSelectionCodeActionPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorSwiftSelectionCodeActionPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorSwiftSelectionCodeActionPluginTests",
            dependencies: ["EditorSwiftSelectionCodeActionPlugin"],
            path: "Tests"
        )
    ]
)
