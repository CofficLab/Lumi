// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ComputerUsePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ComputerUsePlugin", targets: ["ComputerUsePlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ComputerUsePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/ComputerUsePlugin",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ComputerUsePluginTests",
            dependencies: [
                "ComputerUsePlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Tests/ComputerUsePluginTests"
        ),
    ]
)
