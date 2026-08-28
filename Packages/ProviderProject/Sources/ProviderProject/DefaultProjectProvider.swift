import Combine
import Foundation
import KitSuperLog
import os

/// `ProjectProviding` 的内存默认实现。
///
/// 提供最基本的内存项目管理能力（无持久化）：
/// 打开项目、关闭项目、维护内存中的项目列表与文件状态。
/// 需要持久化等完整能力的宿主应提供自己的实现替换。
@MainActor
public final class DefaultProjectProvider: ProjectProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-project", category: "Project")
    public nonisolated static let emoji = "📁"

    @Published public private(set) var currentProject: ProjectInfo?
    @Published public private(set) var projects: [ProjectInfo] = []
    @Published public private(set) var openFileURLs: [URL] = []
    @Published public private(set) var currentFileURL: URL?

    private var observers: [WeakObserver] = []

    public init() {
        Self.logger.warning("\(Self.t)DefaultProjectProvider is an incomplete default implementation")
    }

    public func openProject(at path: String) async throws {
        Self.logger.warning("\(Self.t)DefaultProjectProvider.openProject uses in-memory state only; persistent project support is incomplete")
        let info = ProjectInfo(
            name: (path as NSString).lastPathComponent,
            path: path
        )

        let projectsChanged: Bool
        if !projects.contains(where: { $0.path == path }) {
            projects.append(info)
            projectsChanged = true
        } else {
            projectsChanged = false
        }

        let currentProjectChanged = !sameProject(currentProject, info)
        currentProject = info

        if projectsChanged {
            notify(.projectsChanged(projects))
        }
        if currentProjectChanged {
            notify(.currentProjectChanged(info))
        }
    }

    public func closeProject() async {
        Self.logger.warning("\(Self.t)DefaultProjectProvider.closeProject uses in-memory state only; complete project cleanup is not implemented")
        guard currentProject != nil else { return }
        currentProject = nil
        notify(.currentProjectChanged(nil))
    }

    public func refreshProjects() async throws {
        Self.logger.warning("\(Self.t)DefaultProjectProvider.refreshProjects is incomplete; no persistent project source is available")
        // 骨架阶段：无持久化来源，保持当前内存列表。
    }

    public func updateCurrentFile(_ fileURL: URL?) {
        guard currentFileURL != fileURL else { return }
        currentFileURL = fileURL
        notify(.currentFileChanged(fileURL))
    }

    public func updateOpenFiles(_ fileURLs: [URL]) {
        guard openFileURLs != fileURLs else { return }
        openFileURLs = fileURLs
        notify(.openFilesChanged(fileURLs))
    }

    public func closeFile(_ fileURL: URL) {
        guard openFileURLs.contains(fileURL) else { return }
        openFileURLs.removeAll { $0 == fileURL }

        let didCloseCurrentFile = currentFileURL == fileURL
        if didCloseCurrentFile {
            currentFileURL = nil
        }

        notify(.openFilesChanged(openFileURLs))
        if didCloseCurrentFile {
            notify(.currentFileChanged(nil))
        }
    }

    public func synchronizeProjects(_ projects: [ProjectInfo]) {
        guard self.projects != projects else { return }
        self.projects = projects
        notify(.projectsChanged(projects))
    }

    // MARK: - Observation

    @discardableResult
    public func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: ProjectProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    private func sameProject(_ lhs: ProjectInfo?, _ rhs: ProjectInfo?) -> Bool {
        lhs?.name == rhs?.name && lhs?.path == rhs?.path && lhs?.language == rhs?.language
    }

    private final class Observer: ProjectProvidingObserverHandle {
        private weak var owner: DefaultProjectProvider?
        private let callback: (ProjectProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultProjectProvider, callback: @escaping (ProjectProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: ProjectProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}
