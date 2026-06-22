import EditorService
import Foundation
import Testing
@testable import EditorTabStripPlugin

/// 期望行为：项目路径就绪时应立即恢复；session-only 中间态不应暴露给 Editor。
@MainActor
struct EditorTabRestoreRegressionTests {
    @Test func startObservingRestoresImmediatelyWhenProjectPathIsReady() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        await fixture.persistTabs(
            paths: [fixture.primaryFile.path, fixture.secondaryFile.path],
            activePath: fixture.primaryFile.path
        )

        coordinator.startObserving(
            sessionStore: fixture.sessionStore,
            projectPathProvider: { fixture.projectPath },
            openFile: { url in await fixture.trackOpen(url) },
            openFileSessionOnly: { url in fixture.trackSessionOnly(url) }
        )

        await yieldUntilRestoreTaskCompletes()

        #expect(fixture.sessionStore.tabs.count == 2)
        #expect(fixture.openedURLs == [fixture.primaryFile])
        #expect(fixture.sessionStore.activeSession?.fileURL == fixture.primaryFile)
    }

    @Test func startObservingWithEmptyPathEventuallyRestoresWhenPathBecomesAvailable() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        await fixture.persistTabs(
            paths: [fixture.primaryFile.path],
            activePath: fixture.primaryFile.path
        )

        var projectPath = ""
        coordinator.startObserving(
            sessionStore: fixture.sessionStore,
            projectPathProvider: { projectPath },
            openFile: { url in await fixture.trackOpen(url) },
            openFileSessionOnly: { url in fixture.trackSessionOnly(url) }
        )

        await yieldUntilRestoreTaskCompletes()
        #expect(fixture.sessionStore.tabs.isEmpty, "路径未就绪时不应创建 session")

        projectPath = fixture.projectPath
        await yieldUntilRestoreTaskCompletes()

        #expect(
            fixture.sessionStore.tabs.count == 1,
            "项目路径就绪后应自动恢复，而不必等待 handleProjectPathChange"
        )
        #expect(fixture.openedURLs == [fixture.primaryFile])
    }

    @Test func restoreWithEmptyProjectPathDoesNotCreateSessions() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        await fixture.persistTabs(
            paths: [fixture.primaryFile.path],
            activePath: fixture.primaryFile.path
        )

        coordinator.startObserving(
            sessionStore: fixture.sessionStore,
            projectPathProvider: { "" },
            openFile: { url in await fixture.trackOpen(url) },
            openFileSessionOnly: { url in fixture.trackSessionOnly(url) }
        )

        await yieldUntilRestoreTaskCompletes()

        #expect(fixture.sessionStore.tabs.isEmpty)
        #expect(fixture.openedURLs.isEmpty)
        #expect(fixture.sessionOnlyURLs.isEmpty)
    }

    @Test func restoreTabsDoesNotExposeSessionOnlyGapBeforeOpenFile() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        await fixture.persistTabs(
            paths: [fixture.primaryFile.path],
            activePath: fixture.primaryFile.path
        )

        var phaseOneGapObserved = false
        await coordinator.restoreTabs(
            forProject: fixture.projectPath,
            openFile: { url in
                phaseOneGapObserved = fixture.sessionStore.tabs.count == 1
                    && fixture.service.sessions.activeSessionID != nil
                    && fixture.service.files.currentFileURL == nil
                    && !fixture.service.files.canPreview
                    && !fixture.service.files.isFileLoadInProgress
                await fixture.trackOpen(url)
            },
            openFileSessionOnly: { url in
                fixture.trackSessionOnly(url)
            }
        )

        #expect(
            !phaseOneGapObserved,
            "活跃 session 在 loadFile 开始前不应处于无内容、非 loading 的中间态"
        )
        #expect(fixture.openedURLs == [fixture.primaryFile])
    }

    @Test func slowOpenFileDefersContentUntilCompletion() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        await fixture.persistTabs(
            paths: [fixture.primaryFile.path],
            activePath: fixture.primaryFile.path
        )

        await coordinator.restoreTabs(
            forProject: fixture.projectPath,
            openFile: { url in
                try? await Task.sleep(nanoseconds: 50_000_000)
                fixture.service.sessions.open(at: url)
            },
            openFileSessionOnly: { url in
                _ = fixture.service.sessions.openFile(at: url)
            }
        )

        await fixture.waitUntilFileLoaded(fixture.primaryFile)

        #expect(fixture.service.files.currentFileURL == fixture.primaryFile)
        #expect(fixture.service.files.canPreview)
    }

    @Test func handleProjectPathChangeIgnoresLateRestoreFromPreviousProject() async {
        let fixture = TabRestoreFixture()
        let coordinator = StripCoordinator(store: fixture.store)
        let oldProject = fixture.projectPath
        let newProject = fixture.rootDirectory.appendingPathComponent("GitOK", isDirectory: true).path
        try? FileManager.default.createDirectory(atPath: newProject, withIntermediateDirectories: true)

        await fixture.persistTabs(
            paths: [fixture.primaryFile.path],
            activePath: fixture.primaryFile.path
        )

        coordinator.handleProjectPathChange(
            oldPath: oldProject,
            newPath: newProject,
            sessionStore: fixture.sessionStore,
            openFile: { url in await fixture.trackOpen(url) },
            openFileSessionOnly: { url in fixture.trackSessionOnly(url) }
        )

        await yieldUntilRestoreTaskCompletes()
        #expect(fixture.openedURLs.isEmpty)
        #expect(fixture.sessionOnlyURLs.isEmpty)
    }
}

// MARK: - Fixture

@MainActor
private final class TabRestoreFixture {
    let rootDirectory: URL
    let projectPath: String
    let primaryFile: URL
    let secondaryFile: URL
    let store: StripStore
    let service = EditorService(editorExtensionRegistry: EditorExtensionRegistry())

    var sessionStore: EditorSessionStore { service.sessionStore }

    private(set) var sessionOnlyURLs: [URL] = []
    private(set) var openedURLs: [URL] = []

    init() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-tab-restore-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let primary = root.appendingPathComponent("Active.swift")
        let secondary = root.appendingPathComponent("Other.swift")
        try? "let active = 1\n".write(to: primary, atomically: true, encoding: .utf8)
        try? "let other = 2\n".write(to: secondary, atomically: true, encoding: .utf8)

        rootDirectory = root
        projectPath = root.path
        primaryFile = primary
        secondaryFile = secondary
        store = StripStore(
            baseDirectory: root.appendingPathComponent("EditorTabStrip/projects", isDirectory: true)
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    func persistTabs(paths: [String], activePath: String) async {
        let tabs = paths.map { path in
            EditorTab(
                sessionID: UUID(),
                fileURL: URL(fileURLWithPath: path)
            )
        }
        store.saveTabs(
            projectPath: projectPath,
            tabs: tabs,
            activeTabPath: activePath
        )

        for _ in 0 ..< 100 {
            let (loadedTabs, loadedActive) = store.loadTabs(forProject: projectPath)
            if loadedTabs.count == paths.count, loadedActive == activePath {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("Persisted tabs were not readable before restore")
    }

    func trackSessionOnly(_ url: URL) {
        sessionOnlyURLs.append(url)
        _ = service.sessions.openFileSessionInBackground(at: url)
    }

    func trackOpen(_ url: URL) async {
        openedURLs.append(url)
        service.sessions.open(at: url)
    }

    func waitUntilFileLoaded(_ file: URL) async {
        for _ in 0 ..< 200 {
            if service.files.currentFileURL == file, service.files.canPreview {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("File did not finish loading during restore")
    }
}

@MainActor
private func yieldUntilRestoreTaskCompletes() async {
    await Task.yield()
    try? await Task.sleep(nanoseconds: 30_000_000)
}
