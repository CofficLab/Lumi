import Foundation
import OpenInKit

/// 为标题栏按钮提供当前项目状态，并在项目切换后刷新可用性。
@MainActor
final class OpenInAntigravityToolbarViewModel: ObservableObject {
    let tool: OpenInTool
    /// 强引用能力 Adapter，保证 ViewModel 存续期间能力始终可用。
    private let projectCapability: OpenInProjectCapability
    private var projectObserver: (any OpenInProjectObserverHandle)?

    @Published private(set) var currentProjectPath: String?
    @Published private(set) var isOpening = false

    init(tool: OpenInTool, projectCapability: OpenInProjectCapability) {
        self.tool = tool
        self.projectCapability = projectCapability
        self.currentProjectPath = projectCapability.currentProjectPath
        self.projectObserver = projectCapability.addProjectObserver { [weak self] event in
            guard case let .currentProjectChanged(path) = event else { return }
            self?.currentProjectPath = path
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
