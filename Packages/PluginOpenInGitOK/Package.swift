// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenInGitOK",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInGitOKPlugin",
            targets: ["OpenInGitOKPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "OpenInGitOKPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInGitOKPluginTests",
            dependencies: ["OpenInGitOKPlugin"],
            path: "Tests"
        )
    ]
)
