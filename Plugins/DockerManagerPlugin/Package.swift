// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockerManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DockerManagerPlugin", targets: ["DockerManagerPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
.target(
            name: "DockerManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "DockerManagerPluginTests",
            dependencies: [.target(name: "DockerManagerPlugin")],
            path: "Tests"
        )
    ]
)