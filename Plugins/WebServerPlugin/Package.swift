// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WebServerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WebServerPlugin", targets: ["WebServerPlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/WebServerKit")
    ],
    targets: [
        .target(
            name: "WebServerPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "WebServerKit", package: "WebServerKit")
            ],
            path: "Sources"
        )
    ]
)
