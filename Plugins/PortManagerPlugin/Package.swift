// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PortManagerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "PortManagerPlugin",
            targets: ["PortManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "PortManagerPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)