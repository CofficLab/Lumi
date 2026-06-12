// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorKernel",
            targets: ["EditorKernel"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "EditorKernel",
            dependencies: [
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol")
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorKernelTests",
            dependencies: ["EditorKernel"],
            path: "Tests"
        )
    ]
)
