// swift-tools-version: 6.0
import PackageDescription

// 两个 target 的划分依据是「是否进入生产包」：
//
// - `KitTestIsolation`：只含测试进程判定与目录守卫，无任何测试框架依赖，
//   会被插件的**生产 target** 引用（见各 `*Runtime`）。
// - `KitTestSupport`：临时目录 / 隔离 UserDefaults / 临时存储 Provider，
//   只被各包的 **testTarget** 引用。
//
// 两者若合并成一个 target，测试辅助代码会跟着打进 App；反过来把守卫放进
// testTarget，各插件在生产代码里就无从引用。边界必须切开。
let package = Package(
    name: "KitTestSupport",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitTestIsolation", targets: ["KitTestIsolation"]),
        .library(name: "KitTestSupport", targets: ["KitTestSupport"]),
    ],
    dependencies: [
        // 版本下限与仓库中多数包的 LumiProviders 约束一致（1.6.0），
        // 避免引入本包时把它们连带提升到更高版本。
        // 只需 `StorageProviding` 协议本身——`allVersionDataRootDirectories`
        // 与 `dataRootDirectorySizeInBytes` 都有协议默认实现。
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
    ],
    targets: [
        .target(
            name: "KitTestIsolation",
            path: "Sources/KitTestIsolation"
        ),
        .target(
            name: "KitTestSupport",
            dependencies: [
                "KitTestIsolation",
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: "Sources/KitTestSupport"
        ),
        .testTarget(
            name: "KitTestSupportTests",
            dependencies: [
                "KitTestSupport",
                "KitTestIsolation",
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: "Tests/KitTestSupportTests"
        ),
    ]
)