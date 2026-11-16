import Foundation
import LumiLoggingKit
import os
import ProviderConversation
import ProviderProject

/// 监听「当前对话变化」，把内核当前项目切换到该对话绑定的项目。
///
/// 关注点分离：对话管理器只负责发布选中变化；「项目」领域知识由 Projects
/// 插件消费——选中对话若绑定了项目（`ConversationSummary.projectPath`），
/// 则调用 `ProjectProviding.openProject` 切换到该项目。
///
/// 行为约定：
/// - 仅在对话存在且 `projectPath` 非空时切换；
/// - 与当前项目路径相同则不重复打开；
/// - 当前项目来自外部打开（`.externalOpen`）时，仅让位给启动恢复带来的选中
///   变化（#131）；用户主动切换对话仍必须联动，否则外部打开一次后联动永久失效；
/// - 选中未绑定项目的对话不强关当前项目（用户手动打开的项目不应被误伤）；
/// - 查询对话摘要与打开项目均为异步，失败仅记录日志，不阻塞选中流程。
@MainActor
final class ConversationProjectSyncObserver: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.projects",
        category: "ConversationProjectSyncObserver"
    )
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    private let conversations: any ConversationManaging
    private let project: any ProjectProviding
    private var observer: (any SelectedConversationObserverHandle)?
    private var projectObserver: (any ProjectProvidingObserverHandle)?
    /// 最近一次当前项目变更的原因。`.externalOpen` 代表用户显式意图，
    /// 据此让位避免启动恢复的选中对话覆盖外部打开的项目（#131）。
    private var lastProjectChangeReason: ProjectChangeReason?
    private var pendingConversationID: UUID?
    /// 待处理请求是否来自启动恢复。
    ///
    /// 恢复选中时管理器仍在加载列表（`isLoadingConversations == true`），
    /// 用户点侧栏切换时必然已经加载完成。据此区分「恢复」与「用户操作」。
    private var pendingSelectionIsRestore = false
    private var hasPendingProjectSync = false
    private var projectSyncTask: Task<Void, Never>?

    init(conversations: any ConversationManaging, project: any ProjectProviding) {
        self.conversations = conversations
        self.project = project

        observer = conversations.addSelectedConversationObserver { [weak self] conversationID in
            guard let self else { return }
            self.handleSelectedConversationChanged(conversationID)
        }

        projectObserver = project.addObserver { [weak self] event in
            guard case .currentProjectChanged(_, let reason) = event else { return }
            self?.lastProjectChangeReason = reason
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册当前对话变化观察者")
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
        projectObserver?.cancel()
        projectObserver = nil
        projectSyncTask?.cancel()
        projectSyncTask = nil
        hasPendingProjectSync = false
        pendingSelectionIsRestore = false
    }

    private func handleSelectedConversationChanged(_ conversationID: UUID?) {
        // 在通知发生的当下取快照：drain 是异步的，等它跑到 fetchConversation
        // 之后管理器早已结束加载，届时再问就分不清恢复还是用户切换了。
        pendingSelectionIsRestore = conversations.isLoadingConversations
        pendingConversationID = conversationID
        hasPendingProjectSync = true
        guard projectSyncTask == nil else { return }

        projectSyncTask = Task { @MainActor [weak self] in
            await self?.drainProjectSyncRequests()
        }
    }

    private func drainProjectSyncRequests() async {
        while !Task.isCancelled, hasPendingProjectSync {
            let conversationID = pendingConversationID
            let isRestoreSelection = pendingSelectionIsRestore
            hasPendingProjectSync = false
            guard let conversationID,
                  conversationID == conversations.selectedConversationID,
                  let summary = await conversations.fetchConversation(id: conversationID),
                  !Task.isCancelled,
                  !hasPendingProjectSync,
                  conversationID == conversations.selectedConversationID,
                  let projectPath = summary.projectPath?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !projectPath.isEmpty else {
                continue
            }
            guard project.currentProject?.path != projectPath else { continue }
            // 外部打开（.externalOpen）代表用户显式意图，但只有启动恢复带来的
            // 选中变化需要让步（#131）。用户主动切换对话也是显式意图，必须联动；
            // 若一律让位，外部打开过一次之后联动就会永久失效。
            guard !(isRestoreSelection && lastProjectChangeReason == .externalOpen) else { continue }

            if Self.verbose {
                Self.logger.info("\(Self.t)当前对话绑定项目，切换项目到 \(projectPath, privacy: .public)")
            }
            do {
                try await project.openProject(at: projectPath, reason: .conversationSwitch)
            } catch {
                Self.logger.error("\(Self.t)切换项目失败：\(error.localizedDescription, privacy: .public)")
            }
        }

        projectSyncTask = nil
    }
}
