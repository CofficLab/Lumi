import Foundation
import os
import LumiLoggingKit

/// v4 历史消息迁移服务（后台执行，#394）
///
/// 在 MessageManagerPlugin onBoot 阶段以**后台任务**方式启动（不阻塞内核启动），
/// 通过 `V4MessageReader` 读取 v4 旧库的历史消息，按会话批量导入 v5 `MessageStore`。
/// 复刻历史 `MessageMigrationJob`（commit 2a1dbdafb）的策略：
/// - **后台执行**：legacy 读取在 `V4MessageReader` actor 上，导入写经
///   `Task.detached(.utility)` 落到协作线程池之外，主线程不承担重 IO。
/// - **独立 marker**：marker 写在本插件数据目录的 `migration_state.json`，
///   与会话迁移的 marker 相互独立 —— 已完成会话迁移的用户重启后仍会补迁消息。
/// - **策略开关** `policy`：`.once`（上线用，只迁一次）/ `.always`（测试用）。
///   幂等性始终由 `existingMessageIDs` 去重快照兜底。
/// - **逐会话容错**：单个会话读取/导入失败只记日志并继续，不中断其余会话；
///   只要存在失败就不写 marker，下次启动重试。
/// - **吞错**：所有错误捕获记日志，绝不向上抛 —— onBoot 串行链不能被阻塞。
/// - **marker 时机**：全部成功才写（绝不在迁移前写，防崩了误以为迁完）。
public struct MessageLegacyMigration: SuperLog, Sendable {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-manager")
    nonisolated public static let emoji = "💬"
    nonisolated static let verbose = false

    /// 迁移策略
    public enum MigrationPolicy: Sendable {
        /// 仅迁移一次：首次成功后写 marker，后续启动跳过（上线时的正式策略）。
        case once
        /// 每次启动都迁移：忽略 marker（便于测试幂等性）。
        /// 幂等性仍由去重快照保证，重复迁移不会产生重复数据。
        case always
    }

    /// 迁移策略开关。生产 `.once`；测试可设 `.always`。
    @MainActor public static var policy: MigrationPolicy = .once

    private let reader: V4MessageReader?
    private let store: MessageStore
    private let migrationMarkerURL: URL

    public init(
        reader: V4MessageReader?,
        store: MessageStore,
        destinationRootURL: URL
    ) {
        self.reader = reader
        self.store = store
        self.migrationMarkerURL = destinationRootURL.appendingPathComponent(
            "migration_state.json",
            isDirectory: false
        )
    }

    /// 执行迁移。幂等、吞错。非隔离异步方法：legacy 读取与导入 IO
    /// 都在主线程之外执行。
    func run() async {
        let policy = await Self.policy

        if policy == .once, migrationMarkerExists() {
            if Self.verbose {
                Self.logger.info("\(Self.t)消息迁移跳过(marker 已标记完成)")
            }
            return
        }

        guard let reader else {
            if Self.verbose {
                Self.logger.info("\(Self.t)消息迁移跳过(无 legacy 数据,全新安装或迁移窗口期已过)")
            }
            return
        }

        guard await reader.hasLegacyData() else {
            if Self.verbose {
                Self.logger.info("\(Self.t)消息迁移跳过(无 v4 旧数据)")
            }
            return
        }

        let startTime = Date()
        do {
            // 去重快照：只读 id 列；后续每批导入后增量并入，避免重复全表扫描。
            var existingIDs = await Task.detached(priority: .utility) {
                self.store.existingMessageIDs()
            }.value

            let conversationIDs = try await reader.fetchLegacyConversationIDs()
            var totalImported = 0
            var hadFailures = false

            for conversationID in conversationIDs {
                do {
                    let messages = try await reader.fetchLegacyMessages(for: conversationID)
                    guard !messages.isEmpty else { continue }
                    let store = self.store
                    let knownIDs = existingIDs
                    let result = try await Task.detached(priority: .utility) {
                        try store.importMessages(messages, existingIDs: knownIDs)
                    }.value
                    existingIDs.formUnion(result.insertedIDs)
                    totalImported += result.inserted
                } catch {
                    // 单会话失败继续迁其余会话；不写 marker，下次启动重试。
                    hadFailures = true
                    Self.logger.error("\(Self.t)会话 \(conversationID.uuidString.prefix(8)) 消息迁移失败：\(error.localizedDescription)")
                }
                await Task.yield()
            }

            await reader.releaseLegacySnapshot()

            if hadFailures {
                Self.logger.error("\(Self.t)消息迁移存在失败会话，不写 marker，下次启动重试")
                return
            }

            writeMigrationMarker(importedCount: totalImported)
            let elapsed = Date().timeIntervalSince(startTime)
            if Self.verbose {
                Self.logger.info("\(Self.t)消息迁移完成:会话 \(conversationIDs.count) 个,导入 \(totalImported) 条,耗时 \(String(format: "%.2f", elapsed))s")
            }
        } catch {
            // 吞错 + 记日志,不向上抛(避免阻塞 onBoot 串行链)。
            // 不写 marker,下次启动会重试。
            await reader.releaseLegacySnapshot()
            Self.logger.error("\(Self.t)消息迁移失败,已跳过,下次启动将重试: \(error.localizedDescription)")
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
            Self.logger.error("\(Self.t)写入消息迁移状态失败: \(error.localizedDescription)")
        }
    }
}