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
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.14.0"),
        .package(path: "../EditorLanguageRuntime"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "EditorKernel",
            dependencies: [
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
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
            dependencies: [
                "EditorKernel",
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests"
        )
    ]
)
