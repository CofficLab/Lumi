import Combine
import Foundation

/// 项目功能组件
@MainActor
public final class ProjectComponent: ObservableObject {
    public private(set) var state: ProjectState

    private var stateSubscription: AnyCancellable?

    public init(state: ProjectState = ProjectState()) {
        self.state = state
        subscribeToState()
    }

    private func subscribeToState() {
        stateSubscription = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    public var currentProject: ProjectEntry? { state.currentProject }

    public var projects: [ProjectEntry] { state.projects }

    public func setCurrentProjectPath(_ path: String) {
        state.setCurrentProjectPath(path)
    }

    public func switchToProject(_ entry: ProjectEntry) {
        state.switchToProject(entry)
    }

    public func clearCurrentProject() {
        state.clearCurrentProject()
    }

    public func addProject(_ entry: ProjectEntry) {
        state.addProject(entry)
    }

    public func removeProject(_ entry: ProjectEntry) {
        state.removeProject(entry)
    }
}
