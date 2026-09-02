// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorContracts",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EditorContracts", targets: ["EditorContracts"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "EditorContracts",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
    ]
)
