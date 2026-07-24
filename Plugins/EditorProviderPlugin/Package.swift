// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EditorProviderPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "EditorProviderPlugin", targets: ["EditorProviderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorProviderPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
    ]
)
