import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// 当前项目变化时清空当前对话
///
/// 监听 `kernel.project.objectWillChange`，当 `currentProject.path` 实际发生
/// 变化时，把 `kernel.conversations?.selectedConversationID` 置为 `nil`。
///
/// 触发条件（"不同才清空"语义）：
///   - 新项目路径非空且与上次观察到的路径不一致；
///   - 即「从 nil → 有项目」「有项目 → 另一个项目」「有项目 → nil」都会触发。
///
/// 不触发的场景：
///   - 仅 `currentFileURL` / `openFileURLs` 等无关属性变化（路径未变）；
///   - 项目路径已经一致（避免重复清空）。
///
/// 实现要点：
///   - 入口走 `objectWillChange` 而不是给 `ProjectProviding` 协议加方法，
///     覆盖任何来源（UI 点击、菜单、`openProject` 链路、未来的 deep link）
///     导致的项目变更；
///   - 调用协议现成的 `deselectConversation()`，它只重置
///     `selectedConversationID`，不会再次触发 `kernel.project.objectWillChange`，
///     因此本 hook 不会自我循环；
///   - 不触发 `kernel.conversations.objectWillChange` 回调里的"对话选择 → 项目切换"
///     链路产生反向依赖：`OnConversationSelectedHook` 只在新选中对话有
///     `projectPath` 时才跟随，本 hook 在项目变化时清空对话，二者形成
///     「项目变 → 对话清空；选中绑项目的对话 → 项目跟随」的对称联动。
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

    private weak var kernel: LumiKernel?
    private var cancellable: AnyCancellable?
    private var lastObservedProjectPath: String?

    // MARK: - Lifecycle

    /// 订阅 `kernel.project?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.project` 仍为 `nil`，本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
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

        // 2. 路径实际变了：清空当前对话。
        //    deselectConversation() 在协议默认实现里是 no-op，由具体实现负责把
        //    selectedConversationID 置 nil；它不会触发 kernel.project 的
        //    objectWillChange，因此不会形成自我循环。
        let oldPath = lastObservedProjectPath ?? "<nil>"
        conversations.deselectConversation()

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ Cleared selected conversation because project changed: \(oldPath) → \(newPath ?? "<nil>")")
        }
    }

    // MARK: - Helpers

    /// 标准化路径，避免 "~"、相对路径、重复 `/` 之类的差异被误判成"不同"。
    private func normalized(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
