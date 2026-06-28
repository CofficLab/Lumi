import Combine
import Foundation

// MARK: - EditorService
//
// 编辑器子系统的 **唯一对外门面（Facade）**。
//
// 子门面按职责拆分，详见 `Sources/Facade/`。`EditorService` 负责初始化与子门面组装。
@MainActor
public final class EditorService: ObservableObject {

    // MARK: - Sub-Facades

    public let files: EditorFileService
    public let sessions: EditorSessionService
    public let editing: EditorEditingService
    public let navigation: EditorNavigationService
    public let commands: EditorCommandService
    public let panel: EditorPanelService
    public let theme: EditorThemeService
    public let lsp: EditorLSPService

    // MARK: - Internal Components

    public let state: EditorState
    public let sessionStore: EditorSessionStore

    public var sessionObjectWillChange: AnyPublisher<Void, Never> {
        sessionStore.objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }

    let editorExtensionRegistry: EditorExtensionRegistry

    private var activeSessionChangedObserver: ((EditorSession) -> Void)?
    private var nestedChangeCancellables = Set<AnyCancellable>()
    private var isRefreshingProjectContext = false
    private var pendingProjectContextRefreshPath: String??
    private var projectContextRefreshToken = UUID()

    init(
        editorExtensionRegistry: EditorExtensionRegistry,
        state: EditorState,
        sessionStore: EditorSessionStore
    ) {
        self.editorExtensionRegistry = editorExtensionRegistry
        self.state = state
        self.sessionStore = sessionStore
        self.files = EditorFileService(state: state)
        self.sessions = EditorSessionService(state: state, sessionStore: sessionStore)
        self.editing = EditorEditingService(state: state)
        self.navigation = EditorNavigationService(state: state)
        self.commands = EditorCommandService(state: state)
        self.panel = EditorPanelService(state: state)
        self.theme = EditorThemeService(state: state)
        self.lsp = EditorLSPService(state: state)
        installNestedObservableForwarding()
        installActiveSessionSyncBridge()
        state.installDocumentHighlightPrewarmScheduler(sessionStore: sessionStore)
    }

    public convenience init(editorExtensionRegistry: EditorExtensionRegistry) {
        self.init(
            editorExtensionRegistry: editorExtensionRegistry,
            state: EditorState(editorExtensions: editorExtensionRegistry),
            sessionStore: EditorSessionStore()
        )
    }

    private func installNestedObservableForwarding() {
        state.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &nestedChangeCancellables)

        sessionStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.objectWillChange.send()
                }
            }
            .store(in: &nestedChangeCancellables)
    }

    // MARK: - Project Context & Extensions

    public var projectRootPath: String? {
        get { state.projectRootPath }
        set { state.projectRootPath = newValue }
    }

    public var projectContextSnapshot: EditorProjectContextSnapshot? {
        state.projectContextSnapshot
    }

    public func refreshProjectContext() {
        state.refreshProjectContextSnapshot()
    }

    public func refreshProjectContext(for projectPath: String?) async {
        projectContextRefreshToken = UUID()
        let refreshToken = projectContextRefreshToken

        if isRefreshingProjectContext {
            pendingProjectContextRefreshPath = projectPath
            return
        }

        isRefreshingProjectContext = true
        defer {
            isRefreshingProjectContext = false
            if let pendingPath = pendingProjectContextRefreshPath {
                pendingProjectContextRefreshPath = nil
                Task { @MainActor in
                    await self.refreshProjectContext(for: pendingPath)
                }
            }
        }

        await performProjectContextRefresh(for: projectPath, refreshToken: refreshToken)
    }

    private func performProjectContextRefresh(for projectPath: String?, refreshToken: UUID) async {
        let trimmedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previousPath = state.projectRootPath?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPath.isEmpty else {
            if let previousPath, !previousPath.isEmpty {
                editorExtensionRegistry.closeAllProjectContexts()
            }
            state.projectRootPath = nil
            state.refreshProjectContextSnapshot()
            return
        }

        if let previousPath, !previousPath.isEmpty, previousPath != trimmedPath {
            editorExtensionRegistry.closeAllProjectContexts()
        }

        state.projectRootPath = trimmedPath
        await state.projectContextCapability?.projectOpened(at: trimmedPath)
        guard projectContextRefreshToken == refreshToken else { return }
        guard state.projectRootPath?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPath else {
            return
        }
        state.refreshProjectContextSnapshot()
    }

    var editorFeaturePlugins: [EditorState.EditorPluginInfo] {
        state.editorFeaturePlugins
    }

    func setEditorFeaturePluginEnabled(_ pluginID: String, enabled: Bool) {
        state.setEditorFeaturePluginEnabled(pluginID, enabled: enabled)
    }

    public var projectContextCapability: (any SuperEditorProjectContextCapability)? {
        state.projectContextCapability
    }

    public var semanticCapability: (any SuperEditorSemanticCapability)? {
        state.semanticCapability
    }

    // MARK: - Kernel View Bridge

    public var editorState: SourceEditorState { state.editorState }

    public var focusedTextView: TextView? {
        get { state.focusedTextView }
        set { state.focusedTextView = newValue }
    }

    public var jumpDelegate: EditorJumpToDefinitionDelegate? {
        get { state.jumpDelegate }
        set { state.jumpDelegate = newValue }
    }

    public var editorExtensions: EditorExtensionRegistry { state.editorExtensions }

    // MARK: - Display State

    public var isMarkdownPreviewMode: Bool { state.isMarkdownPreviewMode }

    func toggleMarkdownPreview() {
        state.isMarkdownPreviewMode.toggle()
    }

    // MARK: - Session Snapshot Sync

    public func syncActiveSession(from snapshot: EditorSession) {
        sessions.syncActiveSession(from: snapshot)
    }

    // MARK: - Notification Bridge

    public var onActiveSessionChanged: ((EditorSession) -> Void)? {
        get { activeSessionChangedObserver }
        set {
            activeSessionChangedObserver = newValue
            installActiveSessionSyncBridge()
        }
    }

    private func installActiveSessionSyncBridge() {
        state.onActiveSessionChanged = { [weak self] snapshot in
            guard let self else { return }
            self.sessions.syncActiveSession(from: snapshot)
            self.activeSessionChangedObserver?(snapshot)
        }
        sessionStore.syncActiveSession(from: state.activeSession)
    }

    public func cleanupForTeardown() {
        activeSessionChangedObserver = nil
        state.onActiveSessionChanged = nil
        sessions.cleanupForTeardown()
    }
}
