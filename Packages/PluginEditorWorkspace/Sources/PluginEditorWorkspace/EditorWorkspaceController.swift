import Combine
import EditorService
import Foundation
import ProviderProject

/// Synchronizes the selected Lumi project with editor sessions.
@MainActor
public final class EditorWorkspaceController: ObservableObject {
    @Published public private(set) var rootURL: URL?
    @Published public private(set) var selectedFileURL: URL?

    public let editor: EditorService
    public let project: any ProjectProviding

    private var cancellables = Set<AnyCancellable>()
    private var projectSyncTask: Task<Void, Never>?
    private var sessionSyncTask: Task<Void, Never>?
    private var isRestoringProject = false

    public init(editor: EditorService, project: any ProjectProviding) {
        self.editor = editor
        self.project = project
        bind()
        synchronizeProject()
    }

    deinit {
        projectSyncTask?.cancel()
        sessionSyncTask?.cancel()
    }

    public func openFile(_ url: URL) {
        let normalized = url.standardizedFileURL
        guard contains(normalized), isRegularFile(normalized) else { return }

        editor.sessions.open(at: normalized)
        selectedFileURL = normalized
        persistEditorSessions()
    }

    public func activateTab(id: EditorSession.ID) {
        editor.sessions.activateAndRestoreSession(id: id)
        selectedFileURL = editor.sessions.activeSession?.fileURL?.standardizedFileURL
        persistEditorSessions()
    }

    @discardableResult
    public func closeTab(id: EditorSession.ID) -> EditorSession? {
        let next = editor.sessions.closeSession(id: id)
        if let next {
            editor.sessions.activateAndRestoreSession(id: next.id)
        }
        selectedFileURL = next?.fileURL?.standardizedFileURL
        persistEditorSessions()
        return next
    }

    public func refreshProject() {
        synchronizeProject(force: true)
    }

    private func bind() {
        project.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                self.projectSyncTask?.cancel()
                self.projectSyncTask = Task { @MainActor [weak self] in
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    self?.synchronizeProject()
                }
            }
            .store(in: &cancellables)

        editor.sessionObjectWillChange
            .sink { [weak self] in
                guard let self else { return }
                self.sessionSyncTask?.cancel()
                self.sessionSyncTask = Task { @MainActor [weak self] in
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    self?.persistEditorSessions()
                }
            }
            .store(in: &cancellables)
    }

    private func synchronizeProject(force: Bool = false) {
        let newRoot = project.currentProject
            .map { URL(fileURLWithPath: $0.path, isDirectory: true).standardizedFileURL }

        guard force || newRoot != rootURL else { return }

        isRestoringProject = true
        defer { isRestoringProject = false }

        rootURL = newRoot
        editor.sessions.closeAllSessions()
        editor.projectRootPath = newRoot?.path

        guard newRoot != nil else {
            selectedFileURL = nil
            return
        }

        let restorable = uniqueProjectFiles(project.openFileURLs)
            .filter(isRegularFile)
        let preferred = project.currentFileURL?
            .standardizedFileURL

        for url in restorable where url != preferred {
            editor.sessions.openFileSessionInBackground(at: url)
        }

        if let preferred,
           contains(preferred),
           isRegularFile(preferred) {
            editor.sessions.open(at: preferred)
            selectedFileURL = preferred
        } else if let first = restorable.first {
            editor.sessions.open(at: first)
            selectedFileURL = first
        } else {
            selectedFileURL = nil
        }
    }

    private func persistEditorSessions() {
        guard !isRestoringProject else { return }
        let openFiles = uniqueProjectFiles(editor.sessions.tabs.compactMap(\.fileURL))
        let current = editor.sessions.activeSession?.fileURL?.standardizedFileURL
        project.updateOpenFiles(openFiles)
        project.updateCurrentFile(current)
    }

    private func uniqueProjectFiles(_ urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        return urls.compactMap { url in
            let normalized = url.standardizedFileURL
            guard contains(normalized), seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    private func contains(_ url: URL) -> Bool {
        guard let rootURL else { return false }
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let fileComponents = url.standardizedFileURL.pathComponents
        return fileComponents.starts(with: rootComponents)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
