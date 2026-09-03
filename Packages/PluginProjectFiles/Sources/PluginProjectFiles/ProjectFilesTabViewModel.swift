import Combine
import Foundation
import ProviderProject

@MainActor
public final class ProjectFilesTabViewModel: ObservableObject {
    @Published public private(set) var tabState: ProjectFilesTabState

    private let project: any ProjectProviding

    public init(project: any ProjectProviding) {
        self.project = project
        self.tabState = ProjectFilesTabState(project: project)
    }

    public func reload() {
        tabState = ProjectFilesTabState(project: project)
    }

    public func activate(_ fileURL: URL) {
        project.activateFile(fileURL)
    }

    public func close(_ fileURL: URL) {
        project.closeFile(fileURL)

        // 兼容尚未实现预览文件语义的 ProjectProviding：预览项不在
        // openFileURLs 中时，closeFile 可能不会清除 currentFileURL。
        let normalizedURL = fileURL.standardizedFileURL
        if project.currentFileURL?.standardizedFileURL == normalizedURL,
           !project.openFileURLs.contains(where: { $0.standardizedFileURL == normalizedURL }) {
            project.updateCurrentFile(nil)
        }
    }

    public func closeOthers(keeping fileURL: URL) {
        for otherURL in tabState.fileURLs where otherURL != fileURL {
            project.closeFile(otherURL)
        }
    }

    var projectIsOpen: Bool {
        project.currentProject != nil
    }
}
