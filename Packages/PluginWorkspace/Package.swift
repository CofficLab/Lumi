// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWorkspace",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "WorkspacePlugin", targets: ["WorkspacePlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../SuperLogKit"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "WorkspacePlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
    ]
)