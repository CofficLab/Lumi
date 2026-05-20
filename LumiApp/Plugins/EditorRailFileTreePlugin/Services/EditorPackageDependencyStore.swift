import Foundation
import os
import MagicKit

@MainActor
final class EditorPackageDependencyStore: ObservableObject, SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-tree.packages")

    @Published private(set) var dependencies: [EditorPackageDependency] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var diagnostic: String?

    private var projectRootPath: String = ""
    private var refreshTask: Task<Void, Never>?

    deinit {
        refreshTask?.cancel()
    }

    func setProjectRootPath(_ path: String) {
        guard path != projectRootPath else { return }
        projectRootPath = path
        dependencies = []
        diagnostic = nil
        refresh()
    }

    func refresh() {
        refreshTask?.cancel()
        let path = projectRootPath
        guard !path.isEmpty else { return }

        isLoading = true
        refreshTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) {
                EditorPackageDependencyResolver.resolve(projectRootURL: URL(fileURLWithPath: path))
            }.value
            guard let self, !Task.isCancelled, self.projectRootPath == path else { return }
            self.dependencies = result
            self.diagnostic = result.isEmpty ? "No Swift package dependencies found." : nil
            self.isLoading = false
        }
    }
}
