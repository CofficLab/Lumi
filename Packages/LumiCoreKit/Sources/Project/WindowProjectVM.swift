import Combine
import Foundation

/// Bridge view model for legacy plugin views that expect a project path on the environment.
@MainActor
public final class WindowProjectVM: ObservableObject {
    @Published public var currentProjectPath: String

    private let store: LumiCurrentProjectPathStore
    private var cancellable: AnyCancellable?

    public init(store: LumiCurrentProjectPathStore) {
        self.store = store
        self.currentProjectPath = store.currentProjectPath
        cancellable = NotificationCenter.default
            .publisher(for: .lumiCurrentProjectPathDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let path = notification.userInfo?[LumiCurrentProjectPathUserInfoKey.path] as? String
                    ?? store.currentProjectPath
                if path != currentProjectPath {
                    currentProjectPath = path
                }
            }
    }

    public var isProjectSelected: Bool {
        !currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var currentProjectName: String {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}
