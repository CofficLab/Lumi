import Foundation
import KernelCore
import ProviderDiagnostics
import ProviderUninstall
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
public final class FileLogPlugin: SuperPlugin, SuperLog {
    nonisolated public static let pluginID = "com.coffic.lumi.plugin.file-log"
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.file-log", category: "FileLog")
    public let id = FileLogPlugin.pluginID
    public let order = 1
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.file-log",
        name: "File Log",
        description: "",
        category: .system,
        stage: .stable,
        policy: .required
    )

    private var uninstallObserver: NSObjectProtocol?


    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 从 StorageProviding 获取日志目录
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let currentDirectory = storage.pluginDataDirectory(for: Self.pluginID)
            let legacyDirectory = currentDirectory.deletingLastPathComponent()
                .appendingPathComponent("FileLog", isDirectory: true)
            try? FileLogCoordinator.migrateLegacyDirectory(
                from: legacyDirectory,
                to: currentDirectory
            )
            FileLogRuntimeBridge.logsDirectory = currentDirectory
        }
        FileLogCoordinator.shared.start()
        uninstallObserver = NotificationCenter.default.addObserver(
            forName: .lumiWillUninstall,
            object: nil,
            queue: nil
        ) { _ in
            FileLogCoordinator.shared.stopAndWait()
        }
        kernel.unregisterProvider((any DiagnosticsProviding).self)
        try kernel.registerProvider((any DiagnosticsProviding).self, FileLogCoordinator.shared)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let uninstallObserver {
            NotificationCenter.default.removeObserver(uninstallObserver)
            self.uninstallObserver = nil
        }
        FileLogCoordinator.shared.stop()
    }
}

// MARK: - Runtime Bridge

/// 运行时桥接：持有日志目录路径
enum FileLogRuntimeBridge {
    nonisolated(unsafe) static var logsDirectory: URL?
}
