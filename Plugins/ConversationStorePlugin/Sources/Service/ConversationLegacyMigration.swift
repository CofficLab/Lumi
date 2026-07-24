import Foundation
import LumiKernel
import SuperLogKit
import os

/// v4 历史会话迁移服务
///
/// 在 ConversationStore 插件 onReady 阶段,通过 `LegacyDataProviding` 读取 v4 旧库的
/// 历史会话,批量导入到 v5 的 `ConversationStore`。设计要点(遵守 v4→v5 迁移契约):
///
/// - **迁移策略开关** `policy`:`.once`(上线用,只迁一次)/ `.always`(测试用,每次启动
///   都迁,便于验证幂等)。幂等性始终由 `importSummaries` 的按 id 去重兜底,无论哪种策略
///   都不会产生重复数据。当前默认 `.always`,**上线前改回 `.once`**。
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

    public init(kernel: LumiKernel, store: ConversationStore) {
        self.kernel = kernel
        self.store = store
    }

    /// 执行迁移。幂等、吞错。
    public func run() async {
        let defaults = UserDefaults.standard

        // 幂等:.once 策略下,已迁移过则直接跳过
        if Self.policy == .once, defaults.bool(forKey: Self.migrationMarkerKey) {
            Self.logger.info("\(Self.t)会话迁移跳过(marker 已标记完成)")
            return
        }

        guard let legacy = kernel.legacyData else {
            // 无 legacy 服务(全新安装或迁移窗口期已过)
            Self.logger.info("\(Self.t)会话迁移跳过(无 legacy 服务,全新安装或迁移窗口期已过)")
            return
        }

        guard legacy.hasLegacyData() else {
            // 没有可迁移的旧数据
            defaults.set(true, forKey: Self.migrationMarkerKey)
            Self.logger.info("\(Self.t)会话迁移跳过(无 v4 旧数据)")
            return
        }

        do {
            let summaries = try legacy.fetchLegacyConversations()
            guard !summaries.isEmpty else {
                defaults.set(true, forKey: Self.migrationMarkerKey)
                Self.logger.info("\(Self.t)会话迁移跳过(v4 会话为空)")
                return
            }

            let imported = try await store.importSummaries(summaries)
            // 迁移成功才写 marker(1Password 幂等教训:绝不在迁移前写)
            // 注意:.always 策略下也写 marker,但每次启动不检查它,纯属记录。
            defaults.set(true, forKey: Self.migrationMarkerKey)

            Self.logger.info("\(Self.t)会话迁移完成:读取 \(summaries.count) 条,导入 \(imported) 条 [策略=\(Self.policy == .once ? "once" : "always")]")
        } catch {
            // 吞错 + 记日志,不向上抛(避免阻塞 onReady 串行链)
            // .once 策略下不写 marker,下次启动会重试;.always 策略下本就每次都跑。
            Self.logger.error("\(Self.t)会话迁移失败,已跳过,下次启动将重试: \(error.localizedDescription)")
        }
    }
}
