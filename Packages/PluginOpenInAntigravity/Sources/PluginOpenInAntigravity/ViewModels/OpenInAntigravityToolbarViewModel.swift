import Foundation
import OpenInKit
import ProviderProject

/// 为标题栏按钮提供当前项目状态，并在项目切换后刷新可用性。
@MainActor
final class OpenInAntigravityToolbarViewModel: ObservableObject {
    let tool: OpenInTool
    private var projectObserver: (any ProjectProvidingObserverHandle)?

    @Published private(set) var currentProjectPath: String?
    @Published private(set) var isOpening = false

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        self.tool = tool
        self.currentProjectPath = project?.currentProject?.path
        self.projectObserver = project?.addObserver { [weak self] event in
            guard case let .currentProjectChanged(currentProject, _) = event else { return }
            self?.currentProjectPath = currentProject?.path
        }
    }

    func cancel() {
        projectObserver?.cancel()
        projectObserver = nil
    }

    func openProjectInAntigravity() {
        guard !isOpening, currentProjectPath != nil else { return }
        isOpening = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isOpening = false }
            do {
                _ = try await tool.execute(arguments: [:])
            } catch {
                OpenInAntigravityPlugin.logger.error("\(OpenInAntigravityPlugin.t)Failed to open project in Antigravity: \(error.localizedDescription)")
            }
        }
    }
}
