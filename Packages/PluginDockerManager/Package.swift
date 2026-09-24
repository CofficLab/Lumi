// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDockerManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginDockerManager", targets: ["DockerManagerPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToolbar"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitShell"),
        .package(path: "../KitSuperLog")
    ],
    targets: [
.target(
            name: "DockerManagerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "KitSuperLog", package: "KitSuperLog")
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
