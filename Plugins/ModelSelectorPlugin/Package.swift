// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ModelSelectorPlugin",
    defaultLocalization: "en",
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
        .package(path: "../../Packages/LumiCoreChat"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ModelSelectorPlugin",
            dependencies: [
                .product(name: "LumiCoreChat", package: "LumiCoreChat"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ModelSelectorPluginTests",
            dependencies: [
                "ModelSelectorPlugin",
            ],
            path: "Tests"
        )
    ]
)
