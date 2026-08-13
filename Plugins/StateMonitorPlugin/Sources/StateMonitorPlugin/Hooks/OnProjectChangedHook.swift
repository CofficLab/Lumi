import Combine
import Foundation
import KernelLumi
import os
import SuperLogKit

/// 当前项目变化时校验当前对话归属
///
/// 监听 `kernel.project.objectWillChange`，当 `currentProject.path` 实际发生
/// 变化时，比较当前对话的 `projectPath` 与新项目路径；仅在两者不一致时
/// 把 `kernel.conversations?.selectedConversationID` 置为 `nil`。
///
/// 触发条件（"归属不一致才清空"语义）：
///   - 新项目路径与上次观察到的路径不一致；
///   - 当前存在选中的对话；
///   - 该对话的项目路径与新项目路径不一致。
///
/// 不触发的场景：
///   - 仅 `currentFileURL` / `openFileURLs` 等无关属性变化（路径未变）；
///   - 项目路径已经一致（避免重复清空）。
///   - 当前对话正是新项目下的对话（包括由选中对话触发的项目跟随）。
///
/// 实现要点：
///   - 入口走 `objectWillChange` 而不是给 `ProjectProviding` 协议加方法，
///     覆盖任何来源（UI 点击、菜单、`openProject` 链路、未来的 deep link）
///     导致的项目变更；
///   - 对话不在有限内存缓存中时，通过 `fetchConversation(id:)` 按 ID 查询，
///     避免分页列表中的对话被误判；
///   - 仅在归属不一致时调用协议现成的 `deselectConversation()`，它只重置
///     `selectedConversationID`，不会再次触发 `kernel.project.objectWillChange`，
///     因此本 hook 不会自我循环；
///   - `OnConversationSelectedHook` 为跟随新选中对话而切换项目时，两边路径一致，
///     本 hook 会保留该对话；用户独立切到其他项目时才清空旧对话。
@MainActor
final class OnProjectChangedHook: SuperLog {

    // MARK: - Logging

    nonisolated static let emoji = "📂"
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.state-monitor.hook.project-changed"
    )

    // MARK: - State

    private weak var kernel: KernelLumi?
    private var cancellable: AnyCancellable?
    private var lastObservedProjectPath: String?
    private var validationTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// 订阅 `kernel.project?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.project` 仍为 `nil`，本方法会直接 `return`。
    func attach(kernel: KernelLumi) {
        self.kernel = kernel
        guard let project = kernel.project else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)attach skipped: kernel.project not registered yet")
            }
            return
        }

        // 记录初始值，避免 attach 之后第一次 objectWillChange 把「刚启动时的状态」
        // 误判为「切换」。
        lastObservedProjectPath = normalized(project.currentProject?.path)

        // `ProjectProviding` 协议声明了
        // `ObjectWillChangePublisher == ObservableObjectPublisher`，所以存在类型
        // (`any ProjectProviding`) 的 `objectWillChange` 可用。
        cancellable = project.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleProjectChange()
            }

        if Self.verbose {
            Self.logger.info("\(Self.t)attached to project service, initial path=\(self.lastObservedProjectPath ?? "<nil>")")
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
        validationTask?.cancel()
        validationTask = nil
        lastObservedProjectPath = nil
        kernel = nil
    }

    // MARK: - Handling

    private func handleProjectChange() {
        guard let kernel,
              let project = kernel.project,
              let conversations = kernel.conversations
        else { return }

        let newPath = normalized(project.currentProject?.path)
        defer { lastObservedProjectPath = newPath }

        // 1. objectWillChange 可能为 currentFileURL / openFileURLs 等无关属性
        //    触发，路径未变 → 跳过，避免不必要的对话清空。
        guard newPath != lastObservedProjectPath else { return }

        validationTask?.cancel()
        validationTask = nil

        // 2. 没有当前对话时无需做归属校验。
        guard let selectedID = conversations.selectedConversationID else { return }

        // 3. 优先使用内存缓存，保持常见项目切换链路同步完成。
        if let summary = conversations.conversations.first(where: { $0.id == selectedID }) {
            reconcileSelection(
                expectedConversationID: selectedID,
                conversationProjectPath: summary.projectPath,
                expectedProjectPath: newPath
            )
            return
        }

        // 4. 分页列表可能选中不在 ConversationManager 有限缓存中的对话；
        //    按 ID 查询后再次确认对话和项目仍是本次事件对应的状态。
        validationTask = Task { @MainActor [weak self] in
            let summary = await conversations.fetchConversation(id: selectedID)
            guard !Task.isCancelled, let self else { return }
            self.reconcileSelection(
                expectedConversationID: selectedID,
                conversationProjectPath: summary?.projectPath,
                expectedProjectPath: newPath
            )
        }
    }

    // MARK: - Helpers

    private func reconcileSelection(
        expectedConversationID: UUID,
        conversationProjectPath: String?,
        expectedProjectPath: String?
    ) {
        guard let kernel,
              let project = kernel.project,
              let conversations = kernel.conversations,
              conversations.selectedConversationID == expectedConversationID,
              normalized(project.currentProject?.path) == expectedProjectPath,
              Self.shouldDeselect(
                  conversationProjectPath: conversationProjectPath,
                  newProjectPath: expectedProjectPath
              )
        else { return }

        conversations.deselectConversation()

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Cleared selected conversation because its project \(self.normalized(conversationProjectPath) ?? "<nil>") does not match \(expectedProjectPath ?? "<nil>")")
        }
    }

    static func shouldDeselect(
        conversationProjectPath: String?,
        newProjectPath: String?
    ) -> Bool {
        normalized(conversationProjectPath) != normalized(newProjectPath)
    }

    /// 标准化路径，避免 "~"、相对路径、重复 `/` 之类的差异被误判成"不同"。
    private func normalized(_ path: String?) -> String? {
        Self.normalized(path)
    }

    private static func normalized(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
