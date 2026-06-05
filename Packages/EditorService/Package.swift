// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorService",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "EditorService",
            targets: ["EditorService"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../EditorKernel"),
        .package(path: "../LumiCodeEditSourceEditor"),
        .package(path: "../CodeEditTextView"),
        .package(path: "../CodeEditLanguages"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),
    ],
    targets: [
        .target(
            name: "EditorService",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorServiceTests",
            dependencies: [
                "EditorService",
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
            ],
            path: "Tests"
        ),
    ]
)
