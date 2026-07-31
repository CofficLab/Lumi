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
/// - **marker 时机**:迁移成功才写(绝不在迁移前写),并写入 MessageStore 自己的数据库目录。
@MainActor
public struct MessageLegacyMigration: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-store")
    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) static var verbose = false

    /// 迁移策略(语义同 ConversationLegacyMigration)
    public enum MigrationPolicy {
        case once
        case always
    }

    /// 迁移策略开关。测试期 `.always`,上线前改回 `.once`。
    public static var policy: MigrationPolicy = .once

    private let kernel: LumiKernel
    private let store: MessageStore
    private let progress: MessageMigrationProgressStore
    private let migrationMarkerURL: URL

    public init(
        kernel: LumiKernel,
        store: MessageStore,
        progress: MessageMigrationProgressStore,
        databaseRootURL: URL
    ) {
        self.kernel = kernel
        self.store = store
        self.progress = progress
        self.migrationMarkerURL = databaseRootURL
            .appendingPathComponent("MessageManagerPlugin", isDirectory: true)
            .appendingPathComponent("migration_state.json", isDirectory: false)
    }

    /// 执行迁移。幂等、吞错。
    ///
    /// 读 v4 legacy 库与写 v5 库都在调用方上下文(由 `OnReady` 里的 `Task` 驱动,
    /// 当前是主线程)同步完成;进度更新直接刷新 `@Published` 字段。
    func run() {
        let policy = Self.policy

        // 幂等:.once 策略下,已迁移过则直接跳过
        if policy == .once, migrationMarkerExists() {
            if Self.verbose { Self.logger.info("\(Self.t)消息迁移跳过(marker 已标记完成)") }
            return
        }

        guard let legacy = kernel.legacyData else {
            if Self.verbose { Self.logger.info("\(Self.t)消息迁移跳过(无 legacy 服务,全新安装或迁移窗口期已过)") }
            return
        }

        guard legacy.hasLegacyData() else {
            if Self.verbose { Self.logger.info("\(Self.t)消息迁移跳过(无 v4 旧数据)") }
            return
        }

        // 先读会话列表,据此逐个会话读消息
        let conversations: [LumiConversationSummary]
        do {
            conversations = try legacy.fetchLegacyConversations()
        } catch {
            Self.logger.error("\(Self.t)消息迁移失败:无法读取 v4 会话列表: \(error.localizedDescription)")
            progress.fail()
            return
        }
        guard !conversations.isEmpty else {
            writeMigrationMarker(importedCount: 0)
            if Self.verbose { Self.logger.info("\(Self.t)消息迁移跳过(v4 会话为空,无可迁移消息)") }
            return
        }

        let startTime = Date()
        progress.start(totalConversations: conversations.count)
        if Self.verbose { Self.logger.info("\(Self.t)消息迁移开始:共 \(conversations.count) 个会话") }

        var totalImported = 0
        var totalRead = 0
        var hadFailures = false

        for (index, conversation) in conversations.enumerated() {
            // 读单个会话的消息
            let messages: [LumiChatMessage]
            do {
                messages = try legacy.fetchLegacyMessages(for: conversation.id)
            } catch {
                hadFailures = true
                Self.logger.error("\(Self.t)消息迁移:会话 \(conversation.id) 消息读取失败,跳过该会话: \(error.localizedDescription)")
                progress.tick(importedDelta: 0)
                continue
            }
            totalRead += messages.count

            // 批量导入该会话的消息
            let imported: Int
            if messages.isEmpty {
                imported = 0
            } else {
                do {
                    imported = try store.importMessages(messages)
                } catch {
                    hadFailures = true
                    Self.logger.error("\(Self.t)消息迁移:会话 \(conversation.id) 消息导入失败,跳过该会话: \(error.localizedDescription)")
                    imported = 0
                }
            }
            totalImported += imported

            // 更新进度
            progress.tick(importedDelta: imported)

            // 每 50 个会话打印一次进度(保留日志可观测性)
            if (index + 1) % 50 == 0, Self.verbose {
                Self.logger.info("\(Self.t)消息迁移进度:\(index + 1)/\(conversations.count) 会话,已读取 \(totalRead) 条,已导入 \(totalImported) 条")
            }
        }

        // 只有所有会话都成功处理才写 marker,否则下次启动继续重试失败项。
        if !hadFailures {
            writeMigrationMarker(importedCount: totalImported)
        }
        progress.finish()
        let elapsed = Date().timeIntervalSince(startTime)
        let policyLabel = policy == .once ? "once" : "always"
        if Self.verbose {
            Self.logger.info("\(Self.t)消息迁移完成:共 \(conversations.count) 会话,读取 \(totalRead) 条,导入 \(totalImported) 条,耗时 \(String(format: "%.2f", elapsed))s [策略=\(policyLabel)]")
        }
    }

    private func migrationMarkerExists() -> Bool {
        guard let data = try? Data(contentsOf: migrationMarkerURL),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return false
        }
        return payload["completed"] as? Bool == true
    }

    private func writeMigrationMarker(importedCount: Int) {
        let payload: [String: Any] = [
            "completed": true,
            "importedCount": importedCount,
            "completedAt": ISO8601DateFormatter().string(from: Date()),
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: migrationMarkerURL, options: .atomic)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)写入消息迁移状态失败: \(error.localizedDescription)")
            }
        }
    }
}
