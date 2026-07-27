// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectIssueScannerPlugin",
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
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProjectIssueScannerPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
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
