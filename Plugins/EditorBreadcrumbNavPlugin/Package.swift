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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorBreadcrumbNavPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorBreadcrumbNavPluginTests",
            dependencies: [
                "EditorBreadcrumbNavPlugin",
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        )
    ]
)
