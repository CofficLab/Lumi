// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorOutline",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorOutlinePlugin",
            targets: ["EditorOutlinePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorOutlinePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorOutlinePluginTests",
            dependencies: ["EditorOutlinePlugin"],
            path: "Tests"
        )
    ]
)
