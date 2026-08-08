import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 选中对话后,把它绑定的 Provider/Model 同步到内核全局当前选中
///
/// 监听 `kernel.conversations?.objectWillChange`,当 `selectedConversationID`
/// 真的发生变化时,读取新对话绑定的 `providerID` / `modelName`,在它们与
/// `kernel.llmProvider.selectedProviderID` / `selectedModel` 不一致时,
/// 调用 `selectProvider(id:)` 与 `selectModel(providerID:model:)` 同步过去。
///
/// 触发条件（"不同才同步"语义）：
///   - 新选中对话存在；
///   - 新对话绑定了 provider（`providerID(for:)` 非 nil）；
///   - 与内核全局当前选中不一致(provider 或 model 任一不同)。
///
/// 不触发的场景：
///   - 同一个对话被多次 fire（`objectWillChange` 在 setter 中可能多次回调）；
///   - `selectedConversationID` 变为 `nil`(由 `OnProjectChangedHook` 触发,
///     让"显式关闭项目"语义保持纯粹);
///   - 新对话没绑定 provider(早期对话、未指定供应商);
///   - 已一致(避免无谓触发,也避免覆盖用户刚手动选择的全局值)。
///
/// 不监听的源：
///   - `kernel.llmProvider.objectWillChange` 不订阅。本 hook 是单向的
///     「对话 → 内核全局」,反向应该由 UI/LLM 插件自身处理,不应形成
///     「内核全局变 → 写入某个对话 → 又让本 hook 把全局再覆盖回去」的循环。
///
/// 监听入口走 `objectWillChange`，与 `OnConversationSelectedHook` 共享同一种
/// 触发源；两条 hook 各自维护 `lastObservedConversationID`,互不影响。
@MainActor
final class OnConversationProviderModelSyncHook: SuperLog {

    // MARK: - Logging

    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.state-monitor.hook.conversation-provider-model"
    )

    // MARK: - State

    private weak var kernel: LumiKernel?
    private var cancellable: AnyCancellable?
    private var startupRestoreTask: Task<Void, Never>?
    private var lastObservedConversationID: UUID?

    // MARK: - Lifecycle

    /// 订阅 `kernel.conversations?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.conversations` 或 `kernel.llmProviders` 仍为 `nil`,
    /// 本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
        self.kernel = kernel
        guard let conversations = kernel.conversations,
              kernel.llmProvider != nil
        else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)attach skipped: conversations or llmProviders not registered yet")
            }
            return
        }

        // 记录初始值，避免 attach 之后第一次 objectWillChange 把「刚启动时的状态」
        // 误判为「切换」。
        lastObservedConversationID = conversations.selectedConversationID

        cancellable = conversations.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSelectionChange()
            }

        // Startup may have no selected conversation. Restore the global
        // provider/model from the most recently active conversation after the
        // conversation cache has finished loading.
        startupRestoreTask = Task { @MainActor [weak self, weak kernel] in
            guard let self, let kernel,
                  let conversations = kernel.conversations,
                  let llmProvider = kernel.llmProvider
            else { return }

            while conversations.isLoadingConversations {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            guard !Task.isCancelled,
                  let lastConversation = conversations.sortedConversations.first,
                  let providerID = lastConversation.providerID,
                  !providerID.isEmpty
            else { return }

            llmProvider.selectProvider(id: providerID)
            if let modelName = lastConversation.modelName, !modelName.isEmpty {
                llmProvider.selectModel(providerID: providerID, model: modelName)
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)✅ Restored global provider/model from last conversation \(lastConversation.id.uuidString.prefix(8)): \(providerID)/\(lastConversation.modelName ?? "<nil>")")
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)attached to conversations service, initial selectedID=\(self.lastObservedConversationID?.uuidString.prefix(8) ?? "<nil>")")
        }
    }

    /// 取消订阅。`StateMonitorPlugin` 是 `.alwaysOn` 插件，进程生命周期内
    /// 通常不调用；但保留入口便于未来重构（例如切换为按需启用）。
    ///
    /// 本类自身由 `StateMonitorPlugin` 强引用，plugin 销毁时 hook 也会被
    /// 释放，`AnyCancellable` 在自身 deinit 中会自动 cancel，因此不需要写 deinit。
    func detach() {
        cancellable?.cancel()
        cancellable = nil
        startupRestoreTask?.cancel()
        startupRestoreTask = nil
        lastObservedConversationID = nil
        kernel = nil
    }

    // MARK: - Handling

    private func handleSelectionChange() {
        guard let kernel,
              let conversations = kernel.conversations,
              let llmProvider = kernel.llmProvider
        else { return }

        let newID = conversations.selectedConversationID
        defer { lastObservedConversationID = newID }

        // 1. 同一个 ID 被多次 fire（objectWillChange 在 setter 中可能产生
        //    多次回调，例如 selectedConversationID 与 currentTitle 一起变），
        //    跳过以避免无意义的全局同步。
        guard newID != lastObservedConversationID else { return }

        // 2. 显式取消选中（newID == nil）不触发 —— 由 `OnProjectChangedHook`
        //    维护「项目变 → 对话清空」的语义,本 hook 不应反向把全局 provider
        //    复位成默认值。
        guard let newID else { return }

        // 3. 新对话没绑 provider → 保留当前全局。常见于早期对话或未指定供应商的对话。
        guard let targetProviderID = conversations.providerID(for: newID),
              !targetProviderID.isEmpty
        else { return }

        let targetModel = conversations.modelName(for: newID)

        let currentProviderID = llmProvider.selectedProviderID
        let currentModel = llmProvider.selectedModel

        // 4. 已一致 → 跳过,避免覆盖用户刚手动选择的全局值,也避免无谓触发。
        //    注意 model 的「nil 与 nil」比较:两者都未指定即视为一致。
        guard currentProviderID != targetProviderID
              || currentModel != targetModel
        else { return }

        let oldProvider = currentProviderID ?? "<nil>"
        let oldModel = currentModel ?? "<nil>"
        let resolvedModel = targetModel ?? "<nil>"

        // 5. 写入全局。selectProvider / selectModel 在 `LLMProviderManaging`
        //    协议里都是同步方法,直接调用即可,不需要 Task 包装。
        llmProvider.selectProvider(id: targetProviderID)
        if let targetModel {
            llmProvider.selectModel(providerID: targetProviderID, model: targetModel)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Synced global provider/model from conversation \(newID.uuidString.prefix(8)): \(oldProvider)/\(oldModel) → \(targetProviderID)/\(resolvedModel)")
        }
    }
}
