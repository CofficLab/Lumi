// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelSelectorPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ModelSelectorPlugin",
            targets: ["ModelSelectorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../LLMProviderManagerPlugin"),
    ],
    targets: [
        .target(
            name: "ModelSelectorPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LLMProviderManagerPlugin", package: "LLMProviderManagerPlugin"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ModelSelectorPluginTests",
            dependencies: ["ModelSelectorPlugin"],
            path: "Tests"
        ),
    ]
)
