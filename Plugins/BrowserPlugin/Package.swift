// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrowserPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BrowserPlugin",
            targets: ["BrowserPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "BrowserPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BrowserPluginTests",
            dependencies: ["BrowserPlugin"],
            path: "Tests"
        )
    ]
)
