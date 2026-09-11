import Combine
import Foundation
import KitSuperLog
import os
import ProviderConversation

/// 观察会话存储的外部事件，并将变化同步到设置页 ViewModel。
///
/// - 订阅 `ConversationManaging` 的会话事件（列表变更、选中、删除等）；
/// - 订阅迁移进度变化（迁移完成后重新装载会话列表）。
@MainActor
final class ConversationStoreObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-manager",
        category: "ConversationStoreObserver"
    )
    nonisolated static let verbose = false

    private let capability: any ConversationStoreCapability
    private weak var viewModel: ConversationStoreSettingsViewModel?
    private var conversationHandle: (any ConversationObserverHandle)?
    private var migrationProgress: ConversationMigrationProgressStore?
    private var migrationCancellable: AnyCancellable?

    init(
        capability: any ConversationStoreCapability,
        viewModel: ConversationStoreSettingsViewModel,
        migrationProgress: ConversationMigrationProgressStore?
    ) {
        self.capability = capability
        self.viewModel = viewModel
        self.migrationProgress = migrationProgress

        conversationHandle = capability.addConversationObserver { [weak self] event in
            self?.handle(event)
        }
        migrationCancellable = migrationProgress?.$phase.sink { [weak self] _ in
            self?.handleMigrationChange()
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        migrationCancellable?.cancel()
        migrationCancellable = nil
        migrationProgress = nil
        viewModel = nil
    }

    private func handle(_ event: ConversationEvent) {
        if Self.verbose {
            Self.logger.info("conversation event: \(String(describing: event), privacy: .public)")
        }
        viewModel?.handleConversationEvent(event)
    }

    private func handleMigrationChange() {
        let isActive = migrationProgress?.isActive ?? false
        viewModel?.updateMigration(isActive: isActive)
        if !isActive {
            // 迁移结束（完成或失败）：重新装载会话列表。
            Task { @MainActor [weak self] in
                await self?.viewModel?.reloadConversations()
            }
        }
    }
}
