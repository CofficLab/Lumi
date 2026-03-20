import Foundation

/// 响应 `ProjectContextRequestVM.request`（由 RootView `onChange` 触发）。
@MainActor
enum ProjectContextRequestHandler {
    static func handle(
        request: ProjectContextRequest?,
        container: RootViewContainer
    ) {
        guard let request else { return }

        switch request {
        case let .switchProject(path):
            let handler = ProjectSwitchHandler(
                projectVM: container.ProjectVM,
                promptService: container.promptService,
                slashCommandService: container.slashCommandService,
                messageViewModel: container.messageViewModel
            )
            Task {
                await handler.handle(path: path)
                await MainActor.run { container.projectContextRequestVM.request = nil }
            }

        case .clearProject:
            let handler = ProjectClearHandler(
                conversationVM: container.ConversationVM,
                projectVM: container.ProjectVM,
                promptService: container.promptService,
                slashCommandService: container.slashCommandService,
                messageViewModel: container.messageViewModel
            )
            Task {
                await handler.handle()
                await MainActor.run { container.projectContextRequestVM.request = nil }
            }
        }
    }
}
