import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 全局详细程度变化 → 当前对话
///
/// 监听 `kernel.conversations?.objectWillChange`,检测 `globalVerbosity`
/// 是否发生变化,若是则把全局值同步到当前对话。
///
/// 触发条件（"不同才同步"语义）：
/// - 当前有选中的对话；
/// - 全局详细程度与当前对话绑定的不一致。
///
/// 不触发的场景：
/// - 无选中对话；
/// - 已一致（避免循环：本 hook 写对话 → 触发 objectWillChange →
///   `OnConversationVerbositySyncHook` 发现已一致 → 跳过）。
///
/// 与 `OnConversationVerbositySyncHook` 的关系：
///   - 本 hook 是「全局 → 对话」方向；
///   - `OnConversationVerbositySyncHook` 是「对话 → 全局」方向；
///   - 两者形成对称联动,类似 Provider/Model 的 Hook 3 和 Hook 4。
///
/// 监听入口：
/// - 订阅 `kernel.conversations?.objectWillChange`
/// - 通过比较 `lastObservedGlobalVerbosity` 与当前 `globalVerbosity` 检测变化
@MainActor
final class OnGlobalVerbositySyncHook: SuperLog {

    // MARK: - Logging

    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.state-monitor.hook.global-verbosity"
    )

    // MARK: - State

    private weak var kernel: LumiKernel?
    private var cancellable: AnyCancellable?
    private var lastObservedGlobalVerbosity: LumiResponseVerbosity = .defaultVerbosity

    // MARK: - Lifecycle

    /// 订阅 `kernel.conversations?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.conversations` 仍为 `nil`，本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
        self.kernel = kernel
        guard let conversations = kernel.conversations else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)attach skipped: conversations not registered yet")
            }
            return
        }

        // 记录初始值，避免 attach 之后第一次 objectWillChange 把「刚启动时的状态」
        // 误判为「变化」。
        lastObservedGlobalVerbosity = conversations.globalVerbosity

        cancellable = conversations.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleGlobalChange()
            }

        if Self.verbose {
            Self.logger.info("\(Self.t)attached to conversations service, initial globalVerbosity=\(self.lastObservedGlobalVerbosity.rawValue)")
        }
    }

    /// 取消订阅。
    func detach() {
        cancellable?.cancel()
        cancellable = nil
        kernel = nil
    }

    // MARK: - Handling

    private func handleGlobalChange() {
        guard let kernel,
              let conversations = kernel.conversations
        else { return }

        // 1. 检测 globalVerbosity 是否变化
        let newVerbosity = conversations.globalVerbosity
        guard newVerbosity != lastObservedGlobalVerbosity else { return }
        lastObservedGlobalVerbosity = newVerbosity

        // 2. 无选中对话 → 跳过
        guard let currentID = conversations.selectedConversationID else { return }

        // 3. 当前对话绑定的详细程度
        let currentVerbosity = conversations.verbosity(for: currentID)

        // 4. 已一致 → 跳过（避免循环）
        guard currentVerbosity != newVerbosity else { return }

        let old = currentVerbosity.rawValue
        let new = newVerbosity.rawValue

        // 5. 写回当前对话
        conversations.setVerbosity(newVerbosity, for: currentID)

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Synced global verbosity to conversation \(currentID.uuidString.prefix(8)): \(old) → \(new)")
        }
    }
}
