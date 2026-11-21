// swift-tools-version: 6.0
import PackageDescription

// 本地源码已随迁移合入远程 LumiKitTestSupport（与 LumiProviders 1.24+ 一同解析）。
// 这里保留为测试壳：从远程 product 导入，避免与远程同名 target 冲突。
let package = Package(
    name: "KitTestSupport",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.1"),
    ],
    targets: [
        .testTarget(
            name: "KitTestSupportTests",
            dependencies: [
                .product(name: "KitTestSupport", package: "LumiKitTestSupport"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            path: "Tests/KitTestSupportTests"
        ),
    ]
)