import Foundation
import SuperLogKit
import os

@MainActor
public final class PackageDependencyStore: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = EditorFileTreeV2Plugin.logger

    @Published public private(set) var dependencies: [PackageDependency] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var diagnostic: String?

    private var projectRootPath: String = ""
    private var refreshTask: Task<Void, Never>?

    deinit {
        refreshTask?.cancel()
    }

    public init() {}

    public func setProjectRootPath(_ path: String) {
        guard path != projectRootPath else { return }
        projectRootPath = path
        dependencies = []
        diagnostic = nil
        isLoading = false
        refreshTask?.cancel()
        guard shouldResolve(for: path) else { return }
        refresh()
    }

    public func refresh() {
        refreshTask?.cancel()
        let path = projectRootPath
        guard shouldResolve(for: path) else {
            dependencies = []
            diagnostic = nil
            isLoading = false
            return
        }

        isLoading = true
        refreshTask = Task { @MainActor [weak self] in
            let result = await Task.detached(priority: .utility) {
                PackageDependencyResolver.resolve(projectRootURL: URL(fileURLWithPath: path))
            }.value
            guard let self, !Task.isCancelled, self.projectRootPath == path else { return }
            self.dependencies = result
            self.diagnostic = result.isEmpty ? "No Swift package dependencies found." : nil
            self.isLoading = false
        }
    }

    private func shouldResolve(for path: String) -> Bool {
        guard !path.isEmpty else { return false }
        return PackageDependencyResolver.shouldShowPackageDependencies(
            projectRootURL: URL(fileURLWithPath: path)
        )
    }
}
