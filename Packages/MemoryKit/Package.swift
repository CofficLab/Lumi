// swift-tools-version: 6.0
import PackageDescription

/// MemoryKit — 持久化记忆系统的核心存储与检索逻辑
///
/// 提供基于文件的记忆存储、索引维护和关键词检索能力，
/// 设计参考 Claude Code 的 memdir 系统。
///
/// ## 核心组件
/// - **Models**: MemoryType, MemoryScope, MemoryItem, MemoryError
/// - **Storage**: MemoryStorageService (文件 CRUD + 索引)
/// - **Retrieval**: MemoryRetrievalService (本地关键词匹配检索)
let package = Package(
    name: "MemoryKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MemoryKit",
            targets: ["MemoryKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MemoryKit",
            dependencies: [],
            path: "Sources/MemoryKit"
        ),
        .testTarget(
            name: "MemoryKitTests",
            dependencies: ["MemoryKit"],
            path: "Tests"
        )
    ]
)
