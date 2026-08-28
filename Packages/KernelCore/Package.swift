// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KernelCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KernelCore",
            targets: ["KernelCore"]
        ),
    ],
    dependencies: [
        .package(path: "../EditorContracts"),
    ],
    targets: [
        .target(
            name: "KernelCore",
            dependencies: [
                .product(name: "EditorContracts", package: "EditorContracts"),
            ],
            path: "Sources/KernelCore"
        ),
        .testTarget(
            name: "KernelCoreTests",
            dependencies: ["KernelCore"]
        )
    ]
)
