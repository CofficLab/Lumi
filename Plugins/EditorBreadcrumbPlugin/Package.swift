// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBreadcrumbPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBreadcrumbPlugin",
            targets: ["EditorBreadcrumbPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorBreadcrumbPlugin",
            dependencies: [
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBreadcrumbPluginTests",
            dependencies: ["EditorBreadcrumbPlugin"],
            path: "Tests"
        )
    ]
)
