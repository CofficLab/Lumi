import Foundation
import LumiKernel
import SuperLogKit
import os

/// v4 历史消息迁移 Job。
///
/// 在 MessageStore 插件 onReady 阶段以后台任务方式启动，不阻塞 App 初始化；
/// 通过 `LegacyDataProviding` 读取 v4 旧库的历史消息，批量导入到 v5 的 `MessageStore`。
///
/// 设计要点：
///
/// - **后台执行**：由 `OnReady` 创建异步任务，不阻塞 onReady 串行链。
/// - **迁移策略开关**：`.once` 上线只迁移一次，`.always` 用于测试幂等性。
/// - **吞错**：捕获所有错误并记录日志，不向插件启动流程抛出。
/// - **遍历方式**：先读取会话列表，再逐会话读取并批量导入，控制内存峰值。
/// - **单会话失败不中断整体**：某个会话失败后继续处理后续会话。
/// - **marker 时机**：所有会话成功处理后才写入迁移完成标记。
@MainActor
public struct MessageMigrationJob: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-store")
    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) static var verbose = true

    /// 迁移策略（`.once` 上线用，`.always` 测试用）。
    public enum MigrationPolicy {
        case once
        case always
    }

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
    public func run() async {
        let policy = Self.policy

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

        var existingIDs: Set<String>
        do {
            existingIDs = try await Task.detached(priority: .utility) {
                try store.existingMessageIDs()
            }.value
        } catch {
            Self.logger.error("\(Self.t)消息迁移失败:无法读取现有消息 ID: \(error.localizedDescription)")
            progress.fail()
            return
        }

        for (index, conversation) in conversations.enumerated() {
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

            let imported: Int
            if messages.isEmpty {
                imported = 0
            } else {
                do {
                    let batchExistingIDs = existingIDs
                    let result = try await Task.detached(priority: .utility) {
                        try store.importMessages(messages, existingIDs: batchExistingIDs)
                    }.value
                    existingIDs.formUnion(result.insertedIDs)
                    imported = result.inserted
                } catch {
                    hadFailures = true
                    Self.logger.error("\(Self.t)消息迁移:会话 \(conversation.id) 消息导入失败,跳过该会话: \(error.localizedDescription)")
                    imported = 0
                }
            }
            totalImported += imported
            progress.tick(importedDelta: imported)

            if (index + 1) % 50 == 0, Self.verbose {
                Self.logger.info("\(Self.t)消息迁移进度:\(index + 1)/\(conversations.count) 会话,已读取 \(totalRead) 条,已导入 \(totalImported) 条")
            }

            await Task.yield()
        }

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
