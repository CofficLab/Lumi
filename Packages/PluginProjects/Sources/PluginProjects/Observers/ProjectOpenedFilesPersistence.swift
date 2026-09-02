import Foundation
import ProviderProject

/// 负责将 `ProjectProviding` 的打开文件状态按项目路径持久化并恢复。
///
/// `ProjectProviding` 仍然是运行时唯一数据源；本类型只负责磁盘快照与启动时
/// 恢复，不向 CodeEditor 或其他消费者暴露另一套项目状态。
@MainActor
final class ProjectOpenedFilesPersistence {
    private weak var project: (any ProjectProviding)?
    private let store: ProjectsStore
    private var openedFilesByProject: [String: ProjectOpenedFiles]
    private var observer: (any ProjectProvidingObserverHandle)?
    private var activeProjectPath: String?
    private var isRestoring = false

    init(project: any ProjectProviding, store: ProjectsStore) {
        self.project = project
        self.store = store
        self.openedFilesByProject = store.loadOpenedFiles()

        observer = project.addObserver { [weak self] event in
            self?.handle(event)
        }

        handleCurrentProjectChanged(project.currentProject)
    }

    func cancel() {
        observer?.cancel()
        observer = nil
    }

    private func handle(_ event: ProjectProvidingEvent) {
        switch event {
        case .currentProjectChanged(let project):
            handleCurrentProjectChanged(project)
        case .openFilesChanged, .currentFileChanged:
            persistCurrentProjectState()
        case .projectsChanged:
            break
        }
    }

    private func handleCurrentProjectChanged(_ projectInfo: ProjectInfo?) {
        guard let project else { return }

        guard let projectInfo else {
            activeProjectPath = nil
            withRestoreGuard {
                project.updateOpenFiles([])
                project.updateCurrentFile(nil)
            }
            return
        }

        let projectPath = ProjectsStore.normalizedPath(projectInfo.path)
        activeProjectPath = projectPath

        let stored = openedFilesByProject[projectPath] ?? ProjectOpenedFiles()
        let restored = sanitized(stored)

        withRestoreGuard {
            project.updateOpenFiles(restored.openFileURLs)
            project.updateCurrentFile(restored.currentFileURL)
        }

        if restored != stored {
            openedFilesByProject[projectPath] = restored
            store.saveOpenedFiles(openedFilesByProject)
        }
    }

    private func persistCurrentProjectState() {
        guard !isRestoring,
              let project,
              let activeProjectPath else {
            return
        }

        let snapshot = ProjectOpenedFiles(
            openFileURLs: normalized(project.openFileURLs),
            currentFileURL: normalized(project.currentFileURL)
        )
        guard openedFilesByProject[activeProjectPath] != snapshot else { return }

        openedFilesByProject[activeProjectPath] = snapshot
        store.saveOpenedFiles(openedFilesByProject)
    }

    private func sanitized(_ stored: ProjectOpenedFiles) -> ProjectOpenedFiles {
        ProjectOpenedFiles(
            openFileURLs: normalized(stored.openFileURLs).filter(fileExists),
            currentFileURL: normalized(stored.currentFileURL).flatMap { fileExists($0) ? $0 : nil }
        )
    }

    private func normalized(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        for url in urls.map(\.standardizedFileURL) where !result.contains(url) {
            result.append(url)
        }
        return result
    }

    private func normalized(_ url: URL?) -> URL? {
        url?.standardizedFileURL
    }

    private func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func withRestoreGuard(_ operation: () -> Void) {
        let previousValue = isRestoring
        isRestoring = true
        operation()
        isRestoring = previousValue
    }
}
