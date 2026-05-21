import Foundation
import MagicKit

/// 项目上下文与 Root 系统提示词联动
///
/// 每个窗口拥有独立的 ProjectController 实例，通过 WindowScope 直接访问窗口级 VM。
@MainActor
final class ProjectController: ObservableObject, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false

    private let scope: WindowScope
    private let global: RootContainer

    init(scope: WindowScope, global: RootContainer) {
        self.scope = scope
        self.global = global
    }

    /// 响应 `WindowProjectContextRequestVM` 的请求
    func handleProjectContextRequest(_ request: ProjectContextRequest) async {
        switch request {
        case let .switchProject(path):
            await handleProjectSwitch(path: path)
        case .clearProject:
            await handleProjectClear()
        }
    }

    // MARK: - Private

    private func handleProjectSwitch(path: String) async {

    }

    private func handleProjectClear() async {
        guard scope.projectVM.isProjectSelected else { return }

        scope.conversationVM.setSelectedConversation(nil, reason: "projectClear")
        scope.projectVM.clearProject()

        await applyProjectContext(path: nil)
    }

    private func applyProjectContext(path: String?) async {
        await global.slashCommandService.setCurrentProjectPath(path)
    }
}
