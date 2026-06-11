// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomProblemsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomProblemsPlugin",
            targets: ["EditorBottomProblemsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorBottomProblemsPlugin",
            dependencies: [
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
            name: "EditorBottomProblemsPluginTests",
            dependencies: ["EditorBottomProblemsPlugin"],
            path: "Tests"
        )
    ]
)
