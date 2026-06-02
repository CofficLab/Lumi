// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GoEditorCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "GoEditorCore", targets: ["GoEditorCore"]),
    ],
    dependencies: [
        .package(path: "../ShellKit"),
    ],
    targets: [
        .target(
            name: "GoEditorCore",
            path: "Sources"
            dependencies: [
                "ShellKit",
            ]
        ),
        .testTarget(
            name: "GoEditorCoreTests",
            dependencies: [
                "GoEditorCore",
            ],
            path: "Tests"
        ),
    ]
)
