import Foundation
import LumiKernel
import SuperLogKit
import os

/// v4 历史消息迁移服务(后台执行)
///
/// 在 MessageStore 插件 onReady 阶段,以**后台任务**方式启动(不阻塞 App 初始化),
/// 通过 `LegacyDataProviding` 读取 v4 旧库的历史消息,批量导入到 v5 的 `MessageStore`。
/// 同时通过 `MessageMigrationProgressStore` 回报进度,供状态栏视图显示。
///
/// 设计要点(遵守 v4→v5 迁移契约):
///
/// - **后台执行**:由 `Task.detached` 驱动,不阻塞 onReady 串行链,App 立即可用。
/// - **迁移策略开关** `policy`:`.once`(上线用,只迁一次)/ `.always`(测试用,每次启动
///   都迁,便于验证幂等)。幂等性始终由 `importMessages` 的按 id 去重兜底。当前默认
///   `.always`,**上线前改回 `.once`**。
/// - **吞错**:`do/catch` 捕获所有错误并记日志,**绝不向上抛**。
/// - **遍历方式**:先从 legacy 读会话列表,再逐会话读消息并批量导入。每个会话单独
///   导入(而非全量一次性),控制内存峰值;2 万条消息分摊到几百个会话里。
/// - **单会话失败不中断整体**:某个会话读取/导入失败,记日志后继续后续会话。
/// - **marker 时机**:迁移成功才写(绝不在迁移前写)。
@MainActor
public struct MessageLegacyMigration: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-store")
    nonisolated public static let emoji = "💬"

    /// 迁移策略(语义同 ConversationLegacyMigration)
    public enum MigrationPolicy {
        case once
        case always
    }

    /// 迁移策略开关。测试期 `.always`,上线前改回 `.once`。
    public static var policy: MigrationPolicy = .always

    /// 迁移标记的 UserDefaults key
    private static let migrationMarkerKey = "lumi.v4_migration.messages.completed"

    private let kernel: LumiKernel
    private let store: MessageStore
    private let progress: MessageMigrationProgressStore

    public init(kernel: LumiKernel, store: MessageStore, progress: MessageMigrationProgressStore) {
        self.kernel = kernel
        self.store = store
        self.progress = progress
    }

    /// 执行迁移。幂等、吞错。**应在后台 Task 中调用**(本方法本身不阻塞主线程 ——
    /// 真正的 IO 在 MessageStore actor 上,读 legacy 库在当前 Task 上下文)。
    ///
    /// - Note: 本方法设计为 `nonisolated` 可调用,进度更新通过 `await MainActor.run`
    ///   回主线程刷新 `@Published` 字段。这样可由 `Task.detached` 直接驱动。
    func run() async {
        let defaults = UserDefaults.standard
        let policy = Self.policy
        let markerKey = Self.migrationMarkerKey

        // 幂等:.once 策略下,已迁移过则直接跳过
        if policy == .once, defaults.bool(forKey: markerKey) {
            await Self.logInfo("消息迁移跳过(marker 已标记完成)")
            return
        }

        guard let legacy = kernel.legacyData else {
            await Self.logInfo("消息迁移跳过(无 legacy 服务,全新安装或迁移窗口期已过)")
            return
        }

        guard legacy.hasLegacyData() else {
            defaults.set(true, forKey: markerKey)
            await Self.logInfo("消息迁移跳过(无 v4 旧数据)")
            return
        }

        // 先读会话列表,据此逐个会话读消息
        let conversations: [LumiConversationSummary]
        do {
            conversations = try legacy.fetchLegacyConversations()
        } catch {
            await Self.logError("消息迁移失败:无法读取 v4 会话列表: \(error.localizedDescription)")
            await progress.fail()
            return
        }
        guard !conversations.isEmpty else {
            defaults.set(true, forKey: markerKey)
            await Self.logInfo("消息迁移跳过(v4 会话为空,无可迁移消息)")
            return
        }

        let startTime = Date()
        await progress.start(totalConversations: conversations.count)
        await Self.logInfo("消息迁移开始:共 \(conversations.count) 个会话")

        var totalImported = 0
        var totalRead = 0

        for (index, conversation) in conversations.enumerated() {
            // 读单个会话的消息
            let messages: [LumiChatMessage]
            do {
                messages = try legacy.fetchLegacyMessages(for: conversation.id)
            } catch {
                await Self.logError("消息迁移:会话 \(conversation.id) 消息读取失败,跳过该会话: \(error.localizedDescription)")
                await progress.tick(importedDelta: 0)
                continue
            }
            totalRead += messages.count

            // 批量导入该会话的消息
            let imported: Int
            if messages.isEmpty {
                imported = 0
            } else {
                do {
                    imported = try await store.importMessages(messages)
                } catch {
                    await Self.logError("消息迁移:会话 \(conversation.id) 消息导入失败,跳过该会话: \(error.localizedDescription)")
                    imported = 0
                }
            }
            totalImported += imported

            // 更新进度(回主线程刷新 UI)
            await progress.tick(importedDelta: imported)

            // 每 50 个会话打印一次进度(保留日志可观测性)
            if (index + 1) % 50 == 0 {
                await Self.logInfo("消息迁移进度:\(index + 1)/\(conversations.count) 会话,已读取 \(totalRead) 条,已导入 \(totalImported) 条")
            }
        }

        // 迁移成功才写 marker
        defaults.set(true, forKey: markerKey)
        await progress.finish()
        let elapsed = Date().timeIntervalSince(startTime)
        let policyLabel = policy == .once ? "once" : "always"
        await Self.logInfo("消息迁移完成:共 \(conversations.count) 会话,读取 \(totalRead) 条,导入 \(totalImported) 条,耗时 \(String(format: "%.2f", elapsed))s [策略=\(policyLabel)]")
    }

    // MARK: - 日志辅助(从后台 Task 回主线程记日志,SuperLog.t 需 MainActor isolation)

    private static func logInfo(_ message: String) async {
        await MainActor.run {
            logger.info("\(Self.t)\(message)")
        }
    }

    private static func logError(_ message: String) async {
        await MainActor.run {
            logger.error("\(Self.t)\(message)")
        }
    }
}
