// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeBuild",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginXcodeBuild", targets: ["PluginXcodeBuild"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
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