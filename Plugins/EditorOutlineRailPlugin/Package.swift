// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorOutlineRailPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorOutlineRailPlugin",
            targets: ["EditorOutlineRailPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorOutlineRailPlugin",
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
            name: "EditorOutlineRailPluginTests",
            dependencies: ["EditorOutlineRailPlugin"],
            path: "Tests"
        )
    ]
)
