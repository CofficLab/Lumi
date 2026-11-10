// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeBuild",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(name: "PluginXcodeBuild", targets: ["PluginXcodeBuild"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginXcodeBuild",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
            ],
            path: "Sources/PluginXcodeBuild",
            resources: [
                // 平级 Resources 目录（与 PluginSkill 相同惯例）：用 ../.. 引用，
                // 保留 Skills 目录结构（.copy），否则 Bundle.module 遍历会失败。
                .copy("../../Resources/Skills")
            ]
        ),
        .testTarget(
            name: "PluginXcodeBuildTests",
            dependencies: [
                "PluginXcodeBuild",
                .product(name: "ProviderSkill", package: "LumiProviders"),
            ],
            path: "Tests/PluginXcodeBuildTests"
        ),
    ]
)