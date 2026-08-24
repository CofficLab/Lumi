// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageStreaming",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageStreamingPlugin", targets: ["MessageStreamingPlugin"]),
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageStreamingPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
    ]
)
