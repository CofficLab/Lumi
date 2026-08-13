// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectFileBreadcrumbPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectFileBreadcrumbPlugin",
            targets: ["ProjectFileBreadcrumbPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ProjectFileBreadcrumbPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectFileBreadcrumbPluginTests",
            dependencies: [
                "ProjectFileBreadcrumbPlugin",
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Tests"
        )
    ]
)
