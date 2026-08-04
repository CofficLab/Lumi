import Combine
import Foundation
import LumiKernel
import os

/// 选中会话后跟随其绑定项目
///
/// 监听 `kernel.conversations?.objectWillChange`，当 `selectedConversationID`
/// 发生变化时，把 `kernel.project?.currentProject` 切到该对话的 `projectPath`。
///
/// 触发条件（"不同才切换"语义）：
///   - 新选中对话存在；
///   - 新对话的 `projectPath` 非空；
///   - 当前项目路径与 `projectPath` 不一致；
///   - 至少有一方存在（一边为 `nil` 也视为"不同"，
///     这样"切回已绑定项目的对话"能恢复项目状态）。
///
/// 不触发的场景：
///   - 同一个对话被重复触发（`objectWillChange` 在 setter 中可能多次 fire）；
///   - 新对话无 `projectPath`（保持当前项目，避免误清空）；
///   - 当前项目路径已经一致；
///   - `selectedConversationID` 变为 `nil`（让显式关闭项目的语义保持纯粹）。
///
/// 监听入口走 `objectWillChange`，不直接改 `ConversationManaging` 协议实现，
/// 这样无论选中是通过 UI 点击、键盘快捷键、Agent tool 还是未来的 deep link 触发，
/// 都会被覆盖。
@MainActor
final class OnConversationSelectedHook {

    // MARK: - Logging

    nonisolated static let verbose = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.conversation-list.hook.selected"
    )

    // MARK: - State

    private weak var kernel: LumiKernel?
    private var cancellable: AnyCancellable?
    private var lastObservedConversationID: UUID?

    // MARK: - Lifecycle

    /// 订阅 `kernel.conversations?.objectWillChange`。
    ///
    /// 必须在所有 service 都已注册后调用（建议在插件的 `onReady` 阶段）；
    /// 提前调用可能 `kernel.conversations` 仍为 `nil`，本方法会直接 `return`。
    func attach(kernel: LumiKernel) {
        self.kernel = kernel
        guard let conversations = kernel.conversations else {
            if Self.verbose {
                Self.logger.warning("attach skipped: kernel.conversations not registered yet")
            }
            return
        }

        // 记录初始值，避免 attach 之后第一次 objectWillChange 把"刚启动时的状态"
        // 误判为"切换"。
        lastObservedConversationID = conversations.selectedConversationID

        // `ConversationManaging` 协议声明了
        // `ObjectWillChangePublisher == ObservableObjectPublisher`（与
        // `ProjectProviding` 一致），所以存在类型的 `objectWillChange` 可用。
        cancellable = conversations.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSelectionChange()
            }

        if Self.verbose {
            Self.logger.info("""
            attached to conversations service, initial selectedID=\
            \(self.lastObservedConversationID?.uuidString.prefix(8) ?? "<nil>")
            """)
        }
    }

    /// 取消订阅。`ConversationListPlugin` 是 `.alwaysOn` 插件，进程生命周期内
    /// 通常不调用；但保留入口便于未来重构（例如切换为按需启用）。
    ///
    /// 本类自身由 `ConversationListPlugin` 强引用，plugin 销毁时 hook 也会被
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
              let conversations = kernel.conversations else { return }

        let newID = conversations.selectedConversationID
        defer { lastObservedConversationID = newID }

        // 1. 同一个 ID 被多次 fire（objectWillChange 在 setter 中可能产生
        //    多次回调，例如 selectedConversationID 与 currentTitle 一起变），
        //    跳过以避免无意义的项目切换。
        guard newID != lastObservedConversationID else { return }

        // 2. 显式取消选中（newID == nil）不切项目 —— 让"关闭项目"语义保持纯粹。
        guard let newID,
              let summary = conversations.conversations.first(where: { $0.id == newID })
        else { return }

        // 3. 新对话没绑项目 → 保持当前项目。
        //    （很多早期对话或未指定项目的对话 projectPath 为 nil。）
        guard let rawTargetPath = summary.projectPath,
              !rawTargetPath.isEmpty
        else { return }

        // 4. 标准化路径，避免 "~/foo" 与 "/Users/xxx/foo" 被判成"不同"。
        let targetPath: String = URL(fileURLWithPath: rawTargetPath)
            .standardizedFileURL
            .path
        let currentPath: String? = {
            guard let raw = kernel.project?.currentProject?.path else { return nil }
            return URL(fileURLWithPath: raw).standardizedFileURL.path
        }()

        // 5. 已一致 → 跳过，避免无谓触发。
        guard currentPath != targetPath else { return }

        // 6. 切换项目。openProject 内部会做路径二次标准化、状态广播，
        //    以及触发其他 Hook（如 ConversationManager.observeProjectChanges）。
        let oldPath = currentPath ?? "<nil>"
        let projectService = kernel.project

        Task { @MainActor [projectService] in
            do {
                try await projectService?.openProject(at: targetPath)
                if Self.verbose {
                    Self.logger.info("""
                    ✅ Followed conversation \(newID.uuidString.prefix(8)): \
                    project \(oldPath) → \(targetPath)
                    """)
                }
            } catch {
                Self.logger.error("""
                ❌ Failed to follow conversation \(newID.uuidString.prefix(8)) \
                to project \(targetPath): \(error.localizedDescription)
                """)
            }
        }
    }
}