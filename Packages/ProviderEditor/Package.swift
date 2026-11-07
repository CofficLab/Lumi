// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderEditor",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "ProviderEditor", targets: ["ProviderEditor"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderEditor",
            path: "Sources/EditorContracts"
        ),
        .testTarget(
            name: "EditorContractsTests",
            dependencies: ["ProviderEditor"]
        ),
    ]
)
