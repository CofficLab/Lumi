import Foundation
import LumiLoggingKit
import os

@MainActor
public final class PackageDependencyStore: ObservableObject, SuperLog {
    public nonisolated static let emoji = "📦"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = ProjectFileTreePlugin.logger

    @Published public private(set) var dependencies: [PackageDependency] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var diagnostic: String?

    private var projectRootPath: String = ""
    private var refreshTask: Task<Void, Never>?
    private var workerTask: Task<[PackageDependency], Never>?

    deinit {
        refreshTask?.cancel()
        workerTask?.cancel()
    }

    public init() {}

    public func setProjectRootPath(_ path: String) {
        guard path != projectRootPath else { return }
        projectRootPath = path
        dependencies = []
        diagnostic = nil
        isLoading = false
        refreshTask?.cancel()
        // 不在主线程同步判定 shouldResolve（内部含 contentsOfDirectory），
        // 交由 refresh() 在后台线程内判定。
        refresh()
    }

    public func refresh() {
        refreshTask?.cancel()
        workerTask?.cancel()
        let path = projectRootPath
        guard !path.isEmpty else {
            dependencies = []
            diagnostic = nil
            isLoading = false
            return
        }

        isLoading = true
        refreshTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let worker = Task.detached(priority: .utility) {
                guard !Task.isCancelled else { return [PackageDependency]() }
                guard PackageDependencyResolver.shouldShowPackageDependencies(
                    projectRootURL: URL(fileURLWithPath: path)
                ) else {
                    return [PackageDependency]()
                }
                guard !Task.isCancelled else { return [PackageDependency]() }
                return PackageDependencyResolver.resolve(projectRootURL: URL(fileURLWithPath: path))
            }
            self?.workerTask = worker
            let result = await worker.value
            guard let self, !Task.isCancelled, self.projectRootPath == path else { return }
            self.dependencies = result
            self.diagnostic = result.isEmpty ? "No Swift package dependencies found." : nil
            self.isLoading = false
        }
    }
}
