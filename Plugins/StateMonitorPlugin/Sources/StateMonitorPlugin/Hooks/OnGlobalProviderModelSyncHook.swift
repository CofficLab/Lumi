import Foundation
import LumiKernel
import os

/// 全局 Provider/Model 变化 → 当前对话
///
/// 监听 `kernel.llmProvider` 的 provider/model 变化事件，把全局选择同步到当前对话。
///
/// 触发条件（"不同才同步"语义）：
/// - 当前有选中的对话；
/// - 全局 provider/model 与当前对话绑定的不一致；
/// - 全局 provider 非空（空值表示"未选择"，不写回）。
///
/// 不触发的场景：
/// - 无选中对话；
/// - 全局 provider 为空；
/// - 已一致（避免循环：Hook 3 写全局 → 触发事件 → Hook 4 发现已一致 → 跳过）。
///
/// 与 Hook 3 的关系：
/// - Hook 3: selectedConversationID 变化 → 写全局
/// - Hook 4: 全局 provider/model 变化 → 写当前对话
/// - Hook 4 写回对话时，Hook 3 不会触发（selectedConversationID 没变）
/// - Hook 3 写全局时，Hook 4 会收到事件，但发现已一致会跳过
///
/// 监听入口：
/// - 用 NotificationCenter 订阅 `.lumiSelectedRemoteProviderIDDidChange`、
///   `.lumiSelectedLocalProviderIDDidChange`、`.lumiSelectedModelsDidChange`
/// - 这三个事件由 `LLMProviderManaging` 实现在 provider/model 变化时发出
@MainActor
final class OnGlobalProviderModelSyncHook {

    // MARK: - Logging

    nonisolated static let verbose = true
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.state-monitor.hook.global-provider-model"
    )

    // MARK: - State

    private weak var kernel: LumiKernel?
    private var observers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    /// 订阅全局 provider/model 变化事件。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.conversations` 或 `kernel.llmProvider` 仍为 `nil`，
    /// 本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
        self.kernel = kernel
        guard kernel.conversations != nil,
              kernel.llmProvider != nil
        else {
            if Self.verbose {
                Self.logger.warning("attach skipped: conversations or llmProvider not registered yet")
            }
            return
        }

        // 订阅三个事件
        observers = [
            NotificationCenter.default.addObserver(
                forName: .lumiSelectedRemoteProviderIDDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleGlobalChange() }
            },
            NotificationCenter.default.addObserver(
                forName: .lumiSelectedLocalProviderIDDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleGlobalChange() }
            },
            NotificationCenter.default.addObserver(
                forName: .lumiSelectedModelsDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.handleGlobalChange() }
            }
        ]

        if Self.verbose {
            Self.logger.info("attached to global provider/model change events")
        }
    }

    /// 取消订阅。`StateMonitorPlugin` 是 `.alwaysOn` 插件，进程生命周期内
    /// 通常不调用；但保留入口便于未来重构（例如切换为按需启用）。
    func detach() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        kernel = nil
    }

    // MARK: - Handling

    private func handleGlobalChange() {
        guard let kernel,
              let conversations = kernel.conversations,
              let llmProvider = kernel.llmProvider
        else { return }

        // 1. 无选中对话 → 跳过
        guard let currentID = conversations.selectedConversationID else { return }

        // 2. 全局 provider 为空 → 跳过（空值表示"未选择"，不写回）
        guard let globalProviderID = llmProvider.selectedProviderID,
              !globalProviderID.isEmpty
        else { return }

        let globalModel = llmProvider.selectedModel

        // 3. 当前对话绑定的 provider/model
        let currentProviderID = conversations.providerID(for: currentID)
        let currentModel = conversations.modelName(for: currentID)

        // 4. 已一致 → 跳过（避免循环：Hook 3 写全局 → 触发事件 → Hook 4 发现已一致 → 跳过）
        guard currentProviderID != globalProviderID
              || currentModel != globalModel
        else { return }

        let oldProvider = currentProviderID ?? "<nil>"
        let oldModel = currentModel ?? "<nil>"
        let newProvider = globalProviderID
        let newModel = globalModel ?? "<nil>"

        // 5. 写回当前对话
        conversations.selectProvider(id: globalProviderID, model: globalModel, for: currentID)

        if Self.verbose {
            Self.logger.info("""
            ✅ Synced global provider/model to conversation \
            \(currentID.uuidString.prefix(8)): \
            \(oldProvider)/\(oldModel) → \(newProvider)/\(newModel)
            """)
        }
    }
}
