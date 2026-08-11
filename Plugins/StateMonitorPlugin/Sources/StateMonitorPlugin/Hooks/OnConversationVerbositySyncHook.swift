import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 当前对话的详细程度变化 → 内核全局
///
/// 监听 `kernel.conversations?.objectWillChange`,覆盖两种场景:
///
/// 1. **切换对话**：当 `selectedConversationID` 真的发生变化时,读取新对话
///    绑定的 `verbosity`,在它与 `globalVerbosity` 不一致时同步过去。
/// 2. **当前对话详细程度被修改**：当选中对话未变,但该对话绑定的 verbosity
///    发生变化时（例如用户在 UI 中直接调整了当前对话的详细程度）,同样
///    把新值同步到全局。
///
/// 触发条件（"不同才同步"语义）：
///   - 对话切换：新选中对话存在，且其 verbosity 与全局不一致；
///   - verbosity 变化：当前有选中对话，其 verbosity 与上次记录不一致，
///     且与全局不一致。
///
/// 不触发的场景：
///   - `objectWillChange` 被多次 fire 但选中对话与详细程度均未变；
///   - `selectedConversationID` 变为 `nil`；
///   - 已一致(避免无谓触发,也避免循环：本 hook 写全局 → 触发 objectWillChange
///     → 本 hook 再次检测到已一致 → 跳过)。
///
/// 与 `OnGlobalVerbositySyncHook` 的关系：
///   - 本 hook 是「对话 → 全局」方向（覆盖切换对话 + 修改当前对话详细程度）；
///   - `OnGlobalVerbositySyncHook` 是「全局 → 对话」方向；
///   - 两者形成对称联动,类似 Provider/Model 的 Hook 3 和 Hook 4。
@MainActor
final class OnConversationVerbositySyncHook: SuperLog {

    // MARK: - Logging

    nonisolated static let emoji = "🔄"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.state-monitor.hook.conversation-verbosity"
    )

    // MARK: - State

    private weak var kernel: LumiKernel?
    private var cancellable: AnyCancellable?
    private var lastObservedConversationID: UUID?

    // MARK: - Lifecycle

    /// 订阅 `kernel.conversations?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.conversations` 仍为 `nil`,本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
        self.kernel = kernel
        guard let conversations = kernel.conversations else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)attach skipped: conversations not registered yet")
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

        if Self.verbose {
            Self.logger.info("\(Self.t)attached to conversations service, initial selectedID=\(self.lastObservedConversationID?.uuidString.prefix(8) ?? "<nil>")")
        }
    }

    /// 取消订阅。
    ///
    /// 本类自身由 `StateMonitorPlugin` 强引用，plugin 销毁时 hook 也会被
    /// 释放，`AnyCancellable` 在自身 deinit 中会自动 cancel，因此不需要写 deinit。
    func detach() {
        cancellable?.cancel()
        cancellable = nil
        lastObservedConversationID = nil
        kernel = nil
    }

    // MARK: - Handling

    private func handleSelectionChange() {
        guard let kernel,
              let conversations = kernel.conversations
        else { return }

        let newID = conversations.selectedConversationID
        let conversationChanged = newID != lastObservedConversationID
        defer { lastObservedConversationID = newID }

        // 无选中对话 → 跳过。显式取消选中（newID == nil）不触发 ——
        // 由 `OnProjectChangedHook` 维护「项目变 → 对话清空」的语义。
        guard let currentID = newID else { return }

        let targetVerbosity = conversations.verbosity(for: currentID)
        let currentVerbosity = conversations.globalVerbosity

        // 场景 1：对话切换 → 同步新对话的 verbosity 到全局
        if conversationChanged {
            // 已一致 → 跳过,避免覆盖用户刚手动选择的全局值,也避免无谓触发。
            guard currentVerbosity != targetVerbosity else { return }

            let old = currentVerbosity.rawValue
            let new = targetVerbosity.rawValue

            conversations.setGlobalVerbosity(targetVerbosity)

            if Self.verbose {
                Self.logger.info("\(Self.t)✅ Synced global verbosity from conversation \(currentID.uuidString.prefix(8)): \(old) → \(new)")
            }
            return
        }

        // 场景 2：当前对话的详细程度被修改 → 同步到全局
        // 此时 conversationChanged == false，即选中对话未变。
        // 如果当前对话的 verbosity 与全局不一致，说明用户直接修改了当前对话的详细程度。
        guard currentVerbosity != targetVerbosity else { return }

        let old = currentVerbosity.rawValue
        let new = targetVerbosity.rawValue

        conversations.setGlobalVerbosity(targetVerbosity)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Synced global verbosity from conversation verbosity change \(currentID.uuidString.prefix(8)): \(old) → \(new)")
        }
    }
}
