// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectIssueScanner",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectIssueScannerPlugin",
            targets: ["ProjectIssueScannerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../LLMKit"),
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProjectIssueScannerPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectIssueScannerPluginTests",
            dependencies: ["ProjectIssueScannerPlugin"],
            path: "Tests"
        )
    ]
)
