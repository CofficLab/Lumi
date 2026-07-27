// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RequestLogPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "RequestLogPlugin",
            targets: ["RequestLogPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "RequestLogPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "RequestLogPluginTests",
            dependencies: ["RequestLogPlugin"],
            path: "Tests"
        )
    ]
)
