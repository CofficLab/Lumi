import Foundation
import KernelCore
import ProviderStorage
import KitSuperLog
import os

// MARK: - File Log SuperPlugin

/// 磁盘日志插件
///
/// 通过 OSLogStore 订阅 subsystem == "com.coffic.lumi" 的日志条目，
/// 异步写入磁盘文件。支持自动轮转和过期清理。
///
/// 插件启动时从 `StorageProviding` 获取日志目录，并启动 `FileLogCoordinator`。
/// 插件关闭时停止协调器。
@MainActor
public final class FileLogPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.file-log"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.file-log",
        name: "File Log",
        description: "",
        category: .system,
        stage: .stable,
        policy: .required
    )


    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 从 StorageProviding 获取日志目录
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            FileLogRuntimeBridge.logsDirectory = storage.pluginDataDirectory(for: "FileLog")
        }
        FileLogCoordinator.shared.start()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        FileLogCoordinator.shared.stop()
    }
}

// MARK: - Runtime Bridge

/// 运行时桥接：持有日志目录路径
enum FileLogRuntimeBridge {
    nonisolated(unsafe) static var logsDirectory: URL?
}
