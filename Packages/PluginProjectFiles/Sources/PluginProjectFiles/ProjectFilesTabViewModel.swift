import Combine
import Foundation
import ProviderProject

@MainActor
public final class ProjectFilesTabViewModel: ObservableObject {
    @Published public private(set) var tabState: ProjectFilesTabState

    private let project: any ProjectProviding
    private var projectObserver: (any ProjectProvidingObserverHandle)?

    public init(project: any ProjectProviding) {
        self.project = project
        self.tabState = ProjectFilesTabState(project: project)
        self.projectObserver = project.addObserver { [weak self] _ in
            self?.tabState = ProjectFilesTabState(project: project)
        }
    }

    public func activate(_ fileURL: URL) {
        project.updateCurrentFile(fileURL)
    }

    public func close(_ fileURL: URL) {
        project.closeFile(fileURL)
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
