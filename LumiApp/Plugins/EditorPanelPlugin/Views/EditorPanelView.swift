import MagicKit
import SwiftUI
import Combine
import CodeEditSourceEditor
import UniformTypeIdentifiers

/// 编辑器主视图
struct EditorPanelView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var editorVM: EditorVM

    /// 便利访问
    private var service: EditorService { editorVM.service }
    private var state: EditorState { service.state }
    private var sessionStore: EditorSessionStore { service.sessionStore }

    @State private var isCommandPalettePresented = false
    @State private var draggedTabSessionID: EditorSession.ID?

    /// 标签页持久化存储
    private let tabStore = EditorTabStripStore.shared
    /// 防抖保存的 Task
    @State private var tabSaveTask: Task<Void, Never>?

    var body: some View {
        eventBoundRootView
    }

    private var baseRootView: some View {
        rootLayout
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    private var lifecycleBoundRootView: some View {
        baseRootView
            .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
                // 保存旧项目的标签页
                if !oldPath.isEmpty {
                    saveCurrentTabs(forProject: oldPath)
                }

                // 保存未保存的变更后关闭所有编辑器会话
                if state.hasUnsavedChanges { state.saveNow() }
                sessionStore.closeAll()
                state.loadFile(from: nil)
                refreshProjectContext(for: newPath)

                // 恢复新项目的标签页
                if !newPath.isEmpty {
                    restoreTabs(forProject: newPath)
                }
            }
            .onChange(of: projectVM.selectedFileURL) { _, newURL in
                openOrActivateSession(for: newURL)
            }
            .onChange(of: state.currentFileURL) { _, _ in
                state.refreshDocumentOutline()
                updateBreadcrumbBridge()
            }
            .onChange(of: state.cursorLine) { _, _ in
                updateBreadcrumbBridge()
            }
            .onChange(of: state.documentSymbolProvider.symbols.map(\.id)) { _, _ in
                updateBreadcrumbBridge()
            }
            .onAppear {
                state.projectRootPath = projectVM.currentProject?.path
                refreshProjectContext(for: projectVM.currentProjectPath)
                state.onActiveSessionChanged = { snapshot in
                    sessionStore.syncActiveSession(from: snapshot)
                }
                if projectVM.isFileSelected {
                    openOrActivateSession(for: projectVM.selectedFileURL)
                    state.refreshDocumentOutline()
                }
                updateBreadcrumbBridge()
            }
            .onDisappear {
                // 保存当前项目的标签页
                let projectPath = projectVM.currentProjectPath
                if !projectPath.isEmpty {
                    saveCurrentTabs(forProject: projectPath)
                }

                if state.hasUnsavedChanges { state.saveNow() }
                state.onActiveSessionChanged = nil
                EditorBreadcrumbContextBridge.shared.update(
                    currentFileURL: nil,
                    activeSymbolTrail: [],
                    openSymbol: nil
                )
            }
    }

    private var editorCommandBoundRootView: some View {
        let viewWithPrimaryCommands = lifecycleBoundRootView
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorUndo)) { _ in
                handleEditorCommandEvent("builtin.undo")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorRedo)) { _ in
                handleEditorCommandEvent("builtin.redo")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFormatDocument)) { _ in
                handleEditorCommandEvent("builtin.format-document")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFindReferences)) { _ in
                handleEditorCommandEvent("builtin.find-references")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorQuickFix)) { _ in
                handleEditorCommandEvent("builtin.quick-fix")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorRenameSymbol)) { _ in
                handleEditorCommandEvent("builtin.rename-symbol")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorWorkspaceSymbols)) { _ in
                handleEditorCommandEvent("builtin.workspace-symbols")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorCallHierarchy)) { _ in
                handleEditorCommandEvent("builtin.call-hierarchy")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorToggleFind)) { _ in
                handleEditorCommandEvent("builtin.find")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorSearchInFiles)) { _ in
                handleEditorCommandEvent("builtin.search-in-files")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorShowCommandPalette)) { _ in
                isCommandPalettePresented = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFindNext)) { _ in
                handleEditorCommandEvent("builtin.find-next")
            }

        return viewWithPrimaryCommands
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFindPrevious)) { _ in
                handleEditorCommandEvent("builtin.find-previous")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorReplaceCurrent)) { _ in
                handleEditorCommandEvent("builtin.replace-current")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorReplaceAll)) { _ in
                handleEditorCommandEvent("builtin.replace-all")
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorToggleOutlinePanel)) { _ in
                state.performPanelCommand(.toggleOutline)
            }
    }

    private var eventBoundRootView: some View {
        editorCommandBoundRootView
            .background(editorSheetHosts)
    }

    private var rootLayout: some View {
        VStack(spacing: 0) {
            if projectVM.isFileSelected {
                fileInfoBanner
                editorContent
            } else {
                emptyState
            }
        }
    }

    private var editorSheetHosts: some View {
        let sheets = builtinSheets + state.editorExtensions.sheetSuggestions(state: state).filter {
            $0.id != "builtin.workspace-symbol-sheet" &&
            $0.id != "builtin.call-hierarchy-sheet"
        }
        return ZStack {
            ForEach(sheets) { sheet in
                EmptyView()
                    .sheet(
                        isPresented: Binding(
                            get: { sheet.isPresented(state) },
                            set: { presented in
                                if !presented {
                                    sheet.onDismiss(state)
                                }
                            }
                        )
                    ) {
                        sheet.content(state)
                    }
            }
        }
    }

    private var builtinSheets: [EditorSheetSuggestion] {
        [
            .init(
                id: "builtin.command-palette-sheet",
                order: 0,
                isPresented: { _ in isCommandPalettePresented },
                onDismiss: { _ in isCommandPalettePresented = false },
                content: { state in
                    AnyView(
                        EditorCommandPaletteView(
                            state: state,
                            openEditors: openEditorItems,
                            onOpenFile: openFileFromQuickOpen
                        ) {
                            isCommandPalettePresented = false
                        }
                    )
                }
            )
        ]
    }

    private var activeDocumentSymbolTrail: [EditorDocumentSymbolItem] {
        state.documentSymbolProvider.activeItems(for: state.cursorLine)
    }

    private func updateBreadcrumbBridge() {
        EditorBreadcrumbContextBridge.shared.update(
            currentFileURL: state.currentFileURL,
            activeSymbolTrail: activeDocumentSymbolTrail,
            openSymbol: { [weak state] symbol in
                state?.performOpenItem(.documentSymbol(symbol))
            }
        )
    }

    // MARK: - Editor Content

    /// 编辑器主体（session 驱动）
    @ViewBuilder
    private var editorContent: some View {
        if state.isMarkdownFile {
            if state.isMarkdownPreviewMode {
                markdownPreviewContent
            } else {
                sourceEditorContent
            }
        } else if state.canPreview {
            sourceEditorContent
        } else if state.isBinaryFile, let fileURL = state.currentFileURL {
            FilePreviewView(fileURL: fileURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if projectVM.isFileSelected {
            let _ = state.logger.warning("📝[editorContent] 显示了「不支持的文件」视图. isMarkdownFile=\(state.isMarkdownFile), canPreview=\(state.canPreview), isBinaryFile=\(state.isBinaryFile), currentFileURL=\(state.currentFileURL?.path ?? "nil", privacy: .public), fileName=\(state.fileName, privacy: .public), fileExtension=\(state.fileExtension, privacy: .public), isFileSelected=\(projectVM.isFileSelected), selectedFileURL=\(projectVM.selectedFileURL?.path ?? "nil", privacy: .public)")
            unsupportedFileView
        }
    }

    @ViewBuilder
    private var sourceEditorContent: some View {
        SourceEditorView(state: state)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    @ViewBuilder
    private var markdownPreviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let content = state.content?.string, !content.isEmpty {
                    MarkdownBlockRenderer(markdown: content)
                        .padding(20)
                } else {
                    Text(String(localized: "No content to preview", table: "LumiEditor"))
                        .font(.system(size: 12))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .padding(40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    // MARK: - File Info Banner

    @ViewBuilder
    private var fileInfoBanner: some View {
        if state.isTruncated || !state.isEditable || shouldShowProjectContextWarning {
            VStack(alignment: .leading, spacing: 4) {
                if state.isTruncated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(
                            String(
                                localized: "Preview Truncated for Large File", table: "LumiEditor")
                        )
                        .font(.system(size: 9))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    }
                    if state.canLoadFullFile {
                        Button(String(localized: "Load Full File", table: "LumiEditor")) {
                            state.loadFullFileFromDisk()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 9))
                    }
                }
                if !state.isEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(String(localized: "Large File Read-Only Preview", table: "LumiEditor"))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
                if let warning = projectContextWarningMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(warning)
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.warning.opacity(0.06))
            .background(themeVM.activeAppTheme.workspaceBackgroundColor())
            .zIndex(1)
        }
    }

    private var shouldShowProjectContextWarning: Bool {
        projectContextWarningMessage != nil
    }

    private var projectContextWarningMessage: String? {
        guard let snapshot = state.projectContextSnapshot, snapshot.isStructuredProject else { return nil }
        switch snapshot.contextStatus {
        case .unavailable, .needsResync:
            return String(localized: "Project semantic context is not ready, cross-file semantic capabilities may be unstable.", table: "LumiEditor")
        default:
            break
        }
        guard state.currentFileURL != nil else { return nil }
        if !snapshot.currentFileIsInTarget {
            return String(localized: "Current file is not bound to any build target, cross-file navigation and diagnostics may be unavailable.", table: "LumiEditor")
        }
        if let activeScheme = snapshot.activeScheme,
           let currentTarget = snapshot.currentFilePrimaryTarget,
           !currentTarget.isEmpty,
           !snapshot.activeSchemeBuildableTargets.isEmpty,
           !snapshot.activeSchemeBuildableTargets.contains(currentTarget) {
            return String(localized: "Current file belongs to target '\(currentTarget)', but current scheme '\(activeScheme)' may not cover it.", table: "LumiEditor")
        }
        if snapshot.currentFileMatchedTargets.count > 1 {
            if let preferredTarget = snapshot.currentFilePrimaryTarget, !preferredTarget.isEmpty {
                return String(localized: "Current file belongs to multiple targets; the editor is currently parsing with '\(preferredTarget)' context.", table: "LumiEditor")
            }
            let targets = snapshot.currentFileMatchedTargets.joined(separator: ", ")
            return String(localized: "Current file belongs to multiple targets (\(targets)); semantic results depend on current scheme and configuration.", table: "LumiEditor")
        }
        return nil
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EditorEmptyStateView()
    }

    // MARK: - Unsupported File

    private var unsupportedFileView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Unsupported File", table: "LumiEditor"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(state.fileName)
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab Persistence

    /// 保存当前打开的标签页到持久化存储
    private func saveCurrentTabs(forProject projectPath: String) {
        let activeTabPath = state.currentFileURL?.path
        tabStore.saveTabs(
            projectPath: projectPath,
            tabs: sessionStore.tabs,
            activeTabPath: activeTabPath
        )
    }

    /// 从持久化存储恢复标签页
    private func restoreTabs(forProject projectPath: String) {
        let (persistedTabs, activeTabPath) = tabStore.loadTabs(forProject: projectPath)

        // 过滤掉不存在的文件
        let validTabs = persistedTabs.compactMap { tab -> URL? in
            guard let url = tab.fileURL,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                return nil
            }
            return url
        }

        guard !validTabs.isEmpty else { return }

        // 先打开最后一个保存的活跃标签
        if let activePath = activeTabPath,
           let activateURL = validTabs.first(where: { $0.path == activePath }) {
            projectVM.selectFile(at: activateURL)
        } else if let fallbackURL = validTabs.first {
            projectVM.selectFile(at: fallbackURL)
        }
    }

    /// 防抖保存当前标签页（2 秒延迟，避免频繁写入）
    private func scheduleTabSave() {
        tabSaveTask?.cancel()
        tabSaveTask = Task {
            try? await Task.sleep(for: Duration.seconds(2))
            guard !Task.isCancelled else { return }
            let projectPath = projectVM.currentProjectPath
            if !projectPath.isEmpty {
                saveCurrentTabs(forProject: projectPath)
            }
        }
    }

    private var openEditorItems: [EditorOpenEditorItem] {
        sessionStore.tabs.map { tab in
            EditorOpenEditorItem(
                sessionID: tab.sessionID,
                fileURL: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                isActive: tab.sessionID == sessionStore.activeSessionID,
                recentActivationRank: sessionStore.recentActivationRank(for: tab.sessionID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.recentActivationRank != rhs.recentActivationRank {
                return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
            }
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Session Management

    private func openOrActivateSession(for fileURL: URL?) {
        state.projectRootPath = projectVM.currentProject?.path
        refreshProjectContext(for: projectVM.currentProjectPath)
        guard let session = sessionStore.openOrActivate(fileURL: fileURL) else {
            state.logger.info("📝[openOrActivateSession] session 为 nil → loadFile(nil), fileURL=\(fileURL?.path ?? "nil", privacy: .public)")
            state.loadFile(from: nil)
            return
        }

        state.logger.info("📝[openOrActivateSession] 加载 session 文件: \(session.fileURL?.path ?? "nil", privacy: .public)")
        state.loadFile(from: session.fileURL)
        restoreInteractionState(for: session)
        scheduleTabSave()
    }

    private func refreshProjectContext(for projectPath: String) {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            state.refreshProjectContextSnapshot()
            return
        }
        Task { @MainActor in
            await state.projectContextCapability?.projectOpened(at: trimmedPath)
            state.refreshProjectContextSnapshot()
        }
    }

    private func activateSession(_ tab: EditorTab) {
        _ = sessionStore.activate(sessionID: tab.sessionID)
        if let fileURL = tab.fileURL {
            projectVM.selectFile(at: fileURL)
        }
    }

    private func activateOpenEditor(_ item: EditorOpenEditorItem) {
        _ = sessionStore.activate(sessionID: item.sessionID)
        if let fileURL = item.fileURL {
            projectVM.selectFile(at: fileURL)
        }
    }

    private func openFileFromQuickOpen(
        _ url: URL,
        target: CursorPosition?,
        highlightLine: Bool
    ) {
        openOrActivateSession(for: url)
        guard let target else { return }
        state.performNavigation(.definition(url, target, highlightLine: highlightLine))
    }

    private func closeSession(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        let wasActive = session.id == sessionStore.activeSessionID
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }

        let nextSession = sessionStore.close(sessionID: session.id)
        guard wasActive else { return }

        if let nextFileURL = nextSession?.fileURL {
            projectVM.selectFile(at: nextFileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func closeOtherSessions(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        if state.currentFileURL != session.fileURL, state.hasUnsavedChanges {
            state.saveNow()
        }

        let keptSession = sessionStore.closeOthers(keeping: session.id)
        if let fileURL = keptSession?.fileURL {
            projectVM.selectFile(at: fileURL)
        } else {
            projectVM.clearFileSelection()
        }
    }

    private func navigateBack() {
        guard let session = sessionStore.goBack(),
              let fileURL = session.fileURL else { return }
        projectVM.selectFile(at: fileURL)
        restoreInteractionState(for: session)
    }

    private func navigateForward() {
        guard let session = sessionStore.goForward(),
              let fileURL = session.fileURL else { return }
        projectVM.selectFile(at: fileURL)
        restoreInteractionState(for: session)
    }

    private func togglePinned(_ tab: EditorTab) {
        sessionStore.togglePinned(sessionID: tab.sessionID)
    }

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID { return }

        _ = sessionStore.reorderSession(
            sessionID: draggedTabSessionID,
            before: targetTab?.sessionID
        )
    }

    private func closeOpenEditorItem(_ item: EditorOpenEditorItem) {
        closeSession(
            EditorTab(
                sessionID: item.sessionID,
                fileURL: item.fileURL,
                title: item.title,
                isDirty: item.isDirty,
                isPinned: item.isPinned
            )
        )
    }

    private func closeOtherOpenEditorItems(_ item: EditorOpenEditorItem) {
        closeOtherSessions(
            EditorTab(
                sessionID: item.sessionID,
                fileURL: item.fileURL,
                title: item.title,
                isDirty: item.isDirty,
                isPinned: item.isPinned
            )
        )
    }

    private func togglePinnedOpenEditorItem(_ item: EditorOpenEditorItem) {
        togglePinned(
            EditorTab(
                sessionID: item.sessionID,
                fileURL: item.fileURL,
                title: item.title,
                isDirty: item.isDirty,
                isPinned: item.isPinned
            )
        )
    }

    private func handleEditorCommandEvent(_ commandID: String) {
        guard projectVM.isFileSelected else { return }
        state.performEditorCommand(id: commandID)
    }

    /// 恢复交互状态
    private func restoreInteractionState(for session: EditorSession) {
        let snapshot = session
        state.projectRootPath = state.projectRootPath

        guard let fileURL = snapshot.fileURL else { return }

        let canRestoreImmediately =
            state.currentFileURL == fileURL &&
            state.content != nil &&
            state.focusedTextView != nil

        if canRestoreImmediately {
            state.applySessionRestore(snapshot)
            return
        }

        if state.currentFileURL != fileURL {
            state.loadFile(from: fileURL)
        }
    }
}

// MARK: - Preview

#Preview {
    EditorPanelView()
        .inRootView()
}
