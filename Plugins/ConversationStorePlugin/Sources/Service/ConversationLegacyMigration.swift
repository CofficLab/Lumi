import Foundation
import LumiKernel
import SuperLogKit
import os

/// v4 历史会话迁移服务(后台执行)
///
/// 在 ConversationStore 插件 onReady 阶段,以**后台任务**方式启动(不阻塞 App 初始化),
/// 通过 `LegacyDataProviding` 读取 v4 旧库的历史会话,批量导入到 v5 的 `ConversationStore`。
/// 同时通过 `ConversationMigrationProgressStore` 回报进度,供状态栏 popover 显示。
///
/// 设计要点(遵守 v4→v5 迁移契约):
///
/// - **后台执行**:由 `Task { }` 驱动,不阻塞 onReady 串行链,App 立即可用。
/// - **迁移策略开关** `policy`:`.once`(上线用,只迁一次)/ `.always`(测试用,每次启动
///   都迁,便于验证幂等)。幂等性始终由 `importSummaries` 的按 id 去重兜底。当前默认
///   `.always`,**上线前改回 `.once`**。
/// - **吞错**:`do/catch` 捕获所有错误并记日志,**绝不向上抛** —— 因为 onReady 是串行
///   调度,抛错会阻塞后续所有插件(MessageStorePlugin 等)。
/// - **无 legacy 服务时跳过**:全新安装或迁移窗口期之后,`kernel.legacyData` 为 nil。
/// - **marker 时机**:迁移成功才写(绝不在迁移前写,防崩了误以为迁完)。
@MainActor
public struct ConversationLegacyMigration: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-store")
    nonisolated public static let emoji = "💬"

    /// 迁移策略
    public enum MigrationPolicy {
        /// 仅迁移一次:首次成功后写 marker,后续启动跳过(上线时的正式策略)。
        case once
        /// 每次启动都迁移:忽略 marker,每次都执行(便于测试幂等性,上线前应改回 .once)。
        ///
        /// 幂等性仍由 `importSummaries` 的按 id 去重保证,重复迁移不会产生重复数据。
        case always
    }

    /// 迁移策略开关。
    ///
    /// - 测试期:设为 `.always`,每次启动都跑迁移,便于反复验证幂等和正确性。
    /// - 上线前:改回 `.once`,生产环境只迁一次。
    public static var policy: MigrationPolicy = .always

    /// 迁移标记的 UserDefaults key
    private static let migrationMarkerKey = "lumi.v4_migration.conversations.completed"

    private let kernel: LumiKernel
    private let store: ConversationStore
    private let progress: ConversationMigrationProgressStore

    public init(kernel: LumiKernel, store: ConversationStore, progress: ConversationMigrationProgressStore) {
        self.kernel = kernel
        self.store = store
        self.progress = progress
    }

    /// 执行迁移。幂等、吞错。**应在后台 Task 中调用**(本方法本身不阻塞主线程 ——
    /// 真正的 IO 在 ConversationStore actor 上)。
    func run() async {
        let defaults = UserDefaults.standard
        let policy = Self.policy
        let markerKey = Self.migrationMarkerKey

        // 幂等:.once 策略下,已迁移过则直接跳过
        if policy == .once, defaults.bool(forKey: markerKey) {
            await Self.logInfo("会话迁移跳过(marker 已标记完成)")
            return
        }

        guard let legacy = kernel.legacyData else {
            // 无 legacy 服务(全新安装或迁移窗口期已过)
            await Self.logInfo("会话迁移跳过(无 legacy 服务,全新安装或迁移窗口期已过)")
            return
        }

        guard legacy.hasLegacyData() else {
            // 没有可迁移的旧数据
            defaults.set(true, forKey: markerKey)
            await Self.logInfo("会话迁移跳过(无 v4 旧数据)")
            return
        }

        let startTime = Date()
        await progress.start()
        await Self.logInfo("会话迁移开始")

        do {
            let summaries = try legacy.fetchLegacyConversations()
            await progress.setReadCount(summaries.count)

            guard !summaries.isEmpty else {
                defaults.set(true, forKey: markerKey)
                await progress.finish()
                await Self.logInfo("会话迁移跳过(v4 会话为空)")
                return
            }

            let imported = try await store.importSummaries(summaries)
            await progress.setImportedCount(imported)
            // 迁移成功才写 marker(1Password 幂等教训:绝不在迁移前写)
            defaults.set(true, forKey: markerKey)
            await progress.finish()

            let elapsed = Date().timeIntervalSince(startTime)
            let policyLabel = policy == .once ? "once" : "always"
            await Self.logInfo("会话迁移完成:读取 \(summaries.count) 条,导入 \(imported) 条,耗时 \(String(format: "%.2f", elapsed))s [策略=\(policyLabel)]")
        } catch {
            // 吞错 + 记日志,不向上抛(避免阻塞 onReady 串行链)
            // .once 策略下不写 marker,下次启动会重试;.always 策略下本就每次都跑。
            await progress.fail()
            await Self.logError("会话迁移失败,已跳过,下次启动将重试: \(error.localizedDescription)")
        }
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
