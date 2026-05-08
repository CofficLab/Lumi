// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorService",
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
        .package(path: "../EditorKernelCore"),
        .package(path: "../LumiCodeEditSourceEditor"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.14.0"),
        .package(url: "https://github.com/CodeEditApp/CodeEditTextView", from: "0.12.1"),
        .package(url: "https://github.com/CodeEditApp/CodeEditLanguages", from: "0.1.20"),
        .package(url: "https://github.com/CofficLab/MagicKit", from: "1.5.23"),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", from: "0.25.0"),
    ],
    targets: [
        .target(
            name: "EditorService",
            dependencies: [
                .product(name: "EditorKernelCore", package: "EditorKernelCore"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "MagicKit", package: "MagicKit"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            ]
        ),
        .testTarget(
            name: "EditorServiceTests",
            dependencies: [
                "EditorService",
                .product(name: "EditorKernelCore", package: "EditorKernelCore"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
            ],
            path: "Tests/EditorServiceTests"
        ),
    ]
)
