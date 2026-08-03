import Foundation
import LumiKernel
import os

/// MessageStore 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑:注册 MessageManager、初始化 MessageStore、
/// **以后台任务方式**启动 v4 历史消息迁移(不阻塞 onReady 串行链,App 立即可用)。
@MainActor
public struct MessageStoreOnReadyHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-store")
    nonisolated static let verbose = false

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) async throws {
        let manager = MessageManager(kernel: kernel)
        try kernel.registerMessageManager(manager)

        // Initialize MessageStore with proper database root URL
        let databaseRootURL: URL
        if let storage = kernel.storage {
            databaseRootURL = storage.dataRootDirectory
        } else {
            databaseRootURL = MessageStore.defaultDatabaseRootURL
        }

        do {
            let store = try MessageStore(databaseRootURL: databaseRootURL)
            MessageStoreRuntimeBridge.shared.store = store

            // Job 在后台异步执行，不阻塞 onReady 串行链；后续 Job 可继续放入 Jobs 目录。
            let progress = MessageMigrationProgressStore.shared
            let migrationJob = MessageMigrationJob(
                kernel: kernel,
                store: store,
                progress: progress,
                databaseRootURL: databaseRootURL
            )
            let itemID = "com.coffic.lumi.plugin.message-store.migration.status"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1000000000)
                await migrationJob.run()
                // 迁移完成后移除状态栏项(完成后自动隐藏,符合"完成后不再占用状态栏"的设计)
                if !progress.isActive {
                    kernel.workspace?.unregisterStatusBarItem(id: itemID)
                }
            }

            if Self.verbose {
                Self.logger.info("MessageManagerPlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw MessageStoreError.initializationFailed("MessageManagerPlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}
