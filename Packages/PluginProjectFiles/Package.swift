// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectFiles",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectFilesPlugin",
            targets: ["ProjectFilesPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "ProjectFilesPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
        .testTarget(
            name: "ProjectFilesPluginTests",
            dependencies: [
                "ProjectFilesPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Tests"
        )
    ]
)
