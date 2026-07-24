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
        kernel.registerMessageManager(manager)

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

            // 后台启动 v4 历史消息迁移(不 await,立即返回,onReady 不阻塞)
            //
            // 为什么用 Task { }(继承 MainActor)而非 Task.detached:
            // `LegacyDataProviding` 协议是 @MainActor,读 v4 旧库的 fetch 必须在主线程,
            // detached 调用 `await legacy.fetch...` 也会 hop 回 MainActor,无法真正后台。
            // 而 `store` 是 actor,`importMessages` 会自动 hop 到 actor 执行,不阻塞主线程。
            // 故真正的写库 IO 已经在后台 actor 上,只有"读 legacy + 调度"在主线程,
            // 主线程负担可接受(读 SwiftData fetch 很快,慢的是写)。
            let progress = MessageMigrationProgressStore.shared
            let migration = MessageLegacyMigration(kernel: kernel, store: store, progress: progress)
            let itemID = "com.coffic.lumi.plugin.message-store.migration.status"
            Task { @MainActor in
                await migration.run()
                // 迁移完成后移除状态栏项(完成后自动隐藏,符合"完成后不再占用状态栏"的设计)
                if !progress.isActive {
                    kernel.sharedUI?.unregisterStatusBarItem(id: itemID)
                }
            }

            if Self.verbose {
                Self.logger.info("MessageStorePlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw MessageStoreError.initializationFailed("MessageStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }
}
