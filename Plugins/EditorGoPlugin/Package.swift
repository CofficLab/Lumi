// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorGoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorGoPlugin",
            targets: ["EditorGoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorGoPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorGoPluginTests",
            dependencies: ["EditorGoPlugin"],
            path: "Tests"
        )
    ]
)
