import Combine
import Foundation

@MainActor
public final class ProjectFilesTabViewModel: ObservableObject {
    @Published public private(set) var tabState: ProjectFilesTabState

    private let projectCapability: any ProjectFilesProjectCapability

    init(projectCapability: any ProjectFilesProjectCapability) {
        self.projectCapability = projectCapability
        self.tabState = ProjectFilesTabState(projectCapability: projectCapability)
    }

    public func reload() {
        tabState = ProjectFilesTabState(projectCapability: projectCapability)
    }

    public func activate(_ fileURL: URL) {
        projectCapability.activateFile(fileURL)
    }

    public func close(_ fileURL: URL) {
        projectCapability.closeFile(fileURL)

        // 兼容尚未实现预览文件语义的 Provider：预览项不在
        // openFileURLs 中时，closeFile 可能不会清除 currentFileURL。
        let normalizedURL = fileURL.standardizedFileURL
        if projectCapability.currentFileURL?.standardizedFileURL == normalizedURL,
           !projectCapability.openFileURLs.contains(where: { $0.standardizedFileURL == normalizedURL }) {
            projectCapability.updateCurrentFile(nil)
        }
    }

    public func closeOthers(keeping fileURL: URL) {
        for otherURL in tabState.fileURLs where otherURL != fileURL {
            projectCapability.closeFile(otherURL)
        }
    }

    var projectIsOpen: Bool {
        projectCapability.currentProject != nil
    }
}
