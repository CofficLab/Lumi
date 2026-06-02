// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FileLogPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FileLogPlugin",
            targets: ["FileLogPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "FileLogPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "FileLogPluginTests",
            dependencies: ["FileLogPlugin"],
            path: "Tests"
        )
    ]
)
