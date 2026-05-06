// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorKernelCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorKernelCore",
            targets: ["EditorKernelCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "EditorKernelCore",
            dependencies: [
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol")
            ]
        ),
        .testTarget(
            name: "EditorKernelCoreTests",
            dependencies: ["EditorKernelCore"]
        )
    ]
)
