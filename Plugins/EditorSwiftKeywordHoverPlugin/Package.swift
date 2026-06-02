// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftKeywordHoverPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftKeywordHoverPlugin",
            targets: ["EditorSwiftKeywordHoverPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorSwiftKeywordHoverPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorSwiftKeywordHoverPluginTests",
            dependencies: ["EditorSwiftKeywordHoverPlugin"],
            path: "Tests"
        )
    ]
)
