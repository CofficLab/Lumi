// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBreadcrumbNavPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBreadcrumbNavPlugin",
            targets: ["EditorBreadcrumbNavPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorBreadcrumbNavPlugin",
            dependencies: [
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBreadcrumbNavPluginTests",
            dependencies: ["EditorBreadcrumbNavPlugin"],
            path: "Tests"
        )
    ]
)
