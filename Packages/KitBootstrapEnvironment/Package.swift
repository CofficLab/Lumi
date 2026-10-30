// swift-tools-version: 6.0
import PackageDescription

// 启动环境预检与启动失败归因。
//
// 刻意保持**零依赖**：这套逻辑是宿主启动路径上的纯判定，既不应该拖进
// SwiftData/KernelCore 这类重依赖，也需要能被 App 宿主与插件同时使用。
// 零依赖也让它的测试秒级完成，不受任何远端包克隆速度影响。
let package = Package(
    name: "KitBootstrapEnvironment",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "KitBootstrapEnvironment",
            targets: ["KitBootstrapEnvironment"]
        ),
    ],
    targets: [
        .target(
            name: "KitBootstrapEnvironment",
            path: "Sources/KitBootstrapEnvironment"
        ),
        .testTarget(
            name: "KitBootstrapEnvironmentTests",
            dependencies: ["KitBootstrapEnvironment"],
            path: "Tests/KitBootstrapEnvironmentTests"
        ),
    ]
)
