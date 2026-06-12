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
        self.cancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let path = store.currentProjectPath
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
