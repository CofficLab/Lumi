import Foundation
import KitSuperLog
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

    init(conversations: any ConversationManaging, project: any ProjectProviding) {
        self.conversations = conversations
        self.project = project

        observer = conversations.addSelectedConversationObserver { [weak self] conversationID in
            guard let self else { return }
            self.handleSelectedConversationChanged(conversationID)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册当前对话变化观察者")
        }
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }

    private func handleSelectedConversationChanged(_ conversationID: UUID?) {
        guard let conversationID else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let summary = await self.conversations.fetchConversation(id: conversationID),
                  let projectPath = summary.projectPath?
                      .trimmingCharacters(in: .whitespacesAndNewlines),
                  !projectPath.isEmpty else {
                return
            }
            guard self.project.currentProject?.path != projectPath else { return }

            if Self.verbose {
                Self.logger.info("\(Self.t)当前对话绑定项目，切换项目到 \(projectPath, privacy: .public)")
            }
            do {
                try await self.project.openProject(at: projectPath)
            } catch {
                Self.logger.error("\(Self.t)切换项目失败：\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}