// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorGoCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "EditorGoCore", targets: ["EditorGoCore"]),
    ],
    dependencies: [
        .package(path: "../ShellKit"),
    ],
    targets: [
        .target(
            name: "EditorGoCore",
            dependencies: [
                "ShellKit",
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "EditorGoCoreTests",
            dependencies: [
                "EditorGoCore",
            ],
            path: "Tests"
        ),
    ]
)
