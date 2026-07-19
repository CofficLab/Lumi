// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiKernel",
            targets: ["LumiKernel"]
        ),
    ],
    dependencies: [
        // 核心依赖最少化，只依赖必要的抽象
    ],
    targets: [
        .target(
            name: "LumiKernel",
            dependencies: [],
            path: "Sources/LumiKernel"
        ),
        .testTarget(
            name: "LumiKernelTests",
            dependencies: ["LumiKernel"]
        )
    ]
)