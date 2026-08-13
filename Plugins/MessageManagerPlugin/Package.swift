// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageManagerPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageManagerPlugin", targets: ["MessageManagerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageManagerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
        .testTarget(
            name: "MessageManagerPluginTests",
            dependencies: ["MessageManagerPlugin"],
            path: "Tests"
        ),
    ]
)
