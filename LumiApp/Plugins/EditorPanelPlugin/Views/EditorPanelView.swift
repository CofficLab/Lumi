import MagicKit
import SwiftUI
import Combine
import CodeEditSourceEditor
import UniformTypeIdentifiers

/// 编辑器主视图
struct EditorPanelView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM
    @EnvironmentObject private var themeManager: ThemeManager
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
            .background(themeManager.activeAppTheme.workspaceBackgroundColor())
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
        .background(themeManager.activeAppTheme.workspaceBackgroundColor())
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
            .background(themeManager.activeAppTheme.workspaceBackgroundColor())
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                discoverabilityHeroCard

                HStack(spacing: 12) {
                    primaryDiscoverabilityAction(
                        title: String(localized: "Quick Open", table: "LumiEditor"),
                        subtitle: String(localized: "Search for files, symbols, settings, and commands from a single entry point.", table: "LumiEditor"),
                        systemImage: "magnifyingglass",
                        accent: AppUI.Color.semantic.primary,
                        action: { NotificationCenter.postLumiEditorShowCommandPalette() }
                    )

                    primaryDiscoverabilityAction(
                        title: String(localized: "Editor Settings", table: "LumiEditor"),
                        subtitle: String(localized: "Adjust font size, tab size, line wrapping, minimap, and save behavior.", table: "LumiEditor"),
                        systemImage: "slider.horizontal.3",
                        accent: AppUI.Color.semantic.warning,
                        action: openEditorSettings
                    )
                }

                discoverabilitySection(
                    title: String(localized: "Getting Started", table: "LumiEditor"),
                    subtitle: String(localized: "The most common workflow entry points when you first open the editor.", table: "LumiEditor")
                ) {
                    VStack(spacing: 10) {
                        discoverabilityActionRow(
                            title: String(localized: "Command Palette", table: "LumiEditor"),
                            subtitle: String(localized: "Execute editor commands, or jump to settings / workspace symbols.", table: "LumiEditor"),
                            shortcut: "⌘⇧P",
                            systemImage: "command",
                            action: { NotificationCenter.postLumiEditorShowCommandPalette() }
                        )
                        discoverabilityActionRow(
                            title: String(localized: "Workspace Symbols", table: "LumiEditor"),
                            subtitle: String(localized: "Jump to types, functions, and symbols across the workspace.", table: "LumiEditor"),
                            shortcut: "⌘T",
                            systemImage: "text.magnifyingglass",
                            action: { state.performEditorCommand(id: "builtin.workspace-symbols") }
                        )
                    }
                }

                discoverabilitySection(
                    title: String(localized: "Workbench Capabilities", table: "LumiEditor"),
                    subtitle: String(localized: "These capabilities align most closely with the editor surface in VS Code.", table: "LumiEditor")
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        capabilityCard(
                            title: String(localized: "Outline", table: "LumiEditor"),
                            subtitle: String(localized: "Jump to functions and types via document symbols of the current session.", table: "LumiEditor"),
                            systemImage: "list.bullet.indent",
                            shortcut: nil,
                            action: { state.performPanelCommand(.toggleOutline) }
                        )
                        capabilityCard(
                            title: String(localized: "Find / Replace", table: "LumiEditor"),
                            subtitle: String(localized: "Highlight current matches, replace preview, and navigate multiple results.", table: "LumiEditor"),
                            systemImage: "text.magnifyingglass",
                            shortcut: "⌘F",
                            action: { state.performEditorCommand(id: "builtin.find") }
                        )
                        capabilityCard(
                            title: String(localized: "Session Restore", table: "LumiEditor"),
                            subtitle: String(localized: "Tabs, recently closed recovery, and back-forward navigation preserve workbench state.", table: "LumiEditor"),
                            systemImage: "clock.arrow.circlepath",
                            shortcut: nil,
                            action: { state.performEditorCommand(id: "builtin.command-palette") }
                        )
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 920)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.activeAppTheme.workspaceBackgroundColor())
    }

    private var discoverabilityHeroCard: some View {
        GlassCard(glowColor: AppUI.Color.semantic.primary.opacity(0.22), borderIntensity: 0.12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Code Editor", table: "LumiEditor"))
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                        Text(String(localized: "Discover the editor's main entry points, workbench capabilities, and adjustable parameters — no roadmap needed.", table: "LumiEditor"))
                            .font(.system(size: 13))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.primary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppUI.Color.semantic.primary.opacity(0.12))
                        )
                }

                HStack(spacing: 10) {
                    quickHintChip(String(localized: "Open a file from the project tree", table: "LumiEditor"))
                    quickHintChip(String(localized: "Use Quick Open for files / symbols / settings", table: "LumiEditor"))
                    quickHintChip(String(localized: "Restore sessions and navigation history", table: "LumiEditor"))
                }
            }
        }
    }

    private func primaryDiscoverabilityAction(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassCard(showShadow: false, glowColor: accent.opacity(0.18), borderIntensity: 0.1) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(accent)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(accent.opacity(0.12))
                            )
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func discoverabilitySection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassCard(showShadow: false, borderIntensity: 0.08) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    icon: "sparkles",
                    title: title,
                    subtitle: subtitle
                )

                GlassDivider()

                content()
            }
        }
    }

    private func discoverabilityActionRow(
        title: String,
        subtitle: String,
        shortcut: String?,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassRow {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.primary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(AppUI.Typography.bodyEmphasized)
                            .foregroundColor(AppUI.Color.semantic.textPrimary)
                        Text(subtitle)
                            .font(AppUI.Typography.caption1)
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }

                    Spacer()

                    if let shortcut {
                        Text(shortcut)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.08))
                            )
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func capabilityCard(
        title: String,
        subtitle: String,
        systemImage: String,
        shortcut: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            GlassCard(showShadow: false, borderIntensity: 0.08) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: systemImage)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.primary)
                        Spacer(minLength: 0)
                        if let shortcut {
                            Text(shortcut)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppUI.Color.semantic.textSecondary)
                        }
                    }

                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private func quickHintChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppUI.Color.semantic.textTertiary.opacity(0.08))
            )
    }

    private func openEditorSettings() {
        AppSettingStore.saveSettingsSelection(type: "core", value: SettingTab.editor.rawValue)
        AppSettingStore.savePendingEditorSettingsSearchQuery(nil)
        NotificationCenter.postOpenSettings()
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
            state.loadFile(from: nil)
            return
        }

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
