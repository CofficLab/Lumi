// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorBreadcrumb",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorBreadcrumb",
            targets: ["PluginEditorBreadcrumb"]
        )
    ],
    dependencies: [
        .package(path: "../CodeEditLanguages"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorBreadcrumb",
            dependencies: [
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorBreadcrumb",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorBreadcrumbTests",
            dependencies: ["PluginEditorBreadcrumb"],
            path: "Tests/PluginEditorBreadcrumbTests"
        )
    ]
)
