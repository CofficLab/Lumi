import MagicKit
import SwiftUI
import Combine
import CodeEditSourceEditor
import UniformTypeIdentifiers

/// 编辑器主视图
struct EditorPanelView: View {

    private struct SessionActivation {
        let sessionID: EditorSession.ID
        let fileURL: URL
        let snapshot: EditorSession
    }

    private struct ActivationIntent: Equatable {
        let preferredGroupID: EditorGroup.ID?
        let sessionID: EditorSession.ID
    }

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var editorVM: EditorVM

    /// 便利访问
    private var service: EditorService { editorVM.service }
    private var state: EditorState { service.state }
    private var sessionStore: EditorSessionStore { service.sessionStore }
    private var workbench: EditorWorkbenchState { service.workbench }
    private var hostStore: EditorGroupHostStore { service.hostStore }

    @State private var pendingActivationIntent: ActivationIntent?
    @State private var isCommandPalettePresented = false
    @State private var draggedTabSessionID: EditorSession.ID?

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
            .onChange(of: projectVM.currentProjectPath) { _, newPath in
                refreshProjectContext(for: newPath)
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
            .onChange(of: workbench.activeGroupID) { _, _ in
                guard !consumePendingActivationIntent(for: workbench.activeGroupID) else { return }
                syncEditorToActiveGroup()
            }
            .onAppear {
                state.projectRootPath = projectVM.currentProject?.path
                refreshProjectContext(for: projectVM.currentProjectPath)
                hostStore.setPrimaryState(state)
                state.onActiveSessionChanged = { snapshot in
                    sessionStore.syncActiveSession(from: snapshot)
                    workbench.syncActiveSession(from: snapshot)
                    syncGroupHost(workbench.activeGroupID, from: snapshot)
                }
                hostStore.retainOnly(Set(workbench.leafGroups.map(\.id)))
                if projectVM.isFileSelected {
                    openOrActivateSession(for: projectVM.selectedFileURL)
                    state.refreshDocumentOutline()
                }
                updateBreadcrumbBridge()
            }
            .onDisappear {
                if state.hasUnsavedChanges {
                    state.saveNow()
                }
                for hostedState in hostStore.allStates {
                    if hostedState.hasUnsavedChanges {
                        hostedState.saveNow()
                    }
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorSplitRight)) { _ in
                splitEditor(.horizontal)
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorSplitDown)) { _ in
                splitEditor(.vertical)
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorCloseSplit)) { _ in
                unsplitEditor()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFocusNextGroup)) { _ in
                focusNextGroup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFocusPreviousGroup)) { _ in
                focusPreviousGroup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorMoveToNextGroup)) { _ in
                moveActiveSessionToNextGroup()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lumiEditorMoveToPreviousGroup)) { _ in
                moveActiveSessionToPreviousGroup()
            }
            .onChange(of: workbench.leafGroups.map(\.id)) { _, ids in
                hostStore.retainOnly(Set(ids))
            }
            .background(editorSheetHosts)
    }

    private var rootLayout: some View {
        VStack(spacing: 0) {
            if projectVM.isFileSelected {
                fileInfoBanner
                workbenchContent
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

    private var openEditorItems: [EditorOpenEditorItem] {
        sessionStore.tabs.compactMap { tab in
            let group = workbench.leafGroups.first(where: { group in
                group.sessions.contains(where: { $0.id == tab.sessionID })
            })
            let groupIndex = group.flatMap { targetGroup in
                workbench.leafGroups.firstIndex(where: { $0.id == targetGroup.id })
            }
            return EditorOpenEditorItem(
                sessionID: tab.sessionID,
                fileURL: tab.fileURL,
                title: tab.title,
                isDirty: tab.isDirty,
                isPinned: tab.isPinned,
                groupID: group?.id,
                groupIndex: groupIndex,
                isInActiveGroup: group?.id == workbench.activeGroupID,
                isActive: tab.sessionID == sessionStore.activeSessionID,
                recentActivationRank: sessionStore.recentActivationRank(for: tab.sessionID)
            )
        }
        .sorted { lhs, rhs in
            if lhs.isInActiveGroup != rhs.isInActiveGroup {
                return lhs.isInActiveGroup && !rhs.isInActiveGroup
            }
            if lhs.isActive != rhs.isActive {
                return lhs.isActive && !rhs.isActive
            }
            if lhs.recentActivationRank != rhs.recentActivationRank {
                return (lhs.recentActivationRank ?? .max) < (rhs.recentActivationRank ?? .max)
            }
            if lhs.groupIndex != rhs.groupIndex {
                return (lhs.groupIndex ?? .max) < (rhs.groupIndex ?? .max)
            }
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    // MARK: - Workbench Content (Phase 4)

    /// 渲染编辑器工作台（group 树）
    @ViewBuilder
    private var workbenchContent: some View {
        Group {
            if workbench.rootGroup.isLeaf {
                // 单编辑器模式：直接渲染
                editorContent
            } else {
                // 多分栏模式：渲染 group 树
                EditorGroupView(
                    group: workbench.rootGroup,
                    workbench: workbench,
                    editorState: state,
                    hostStore: hostStore,
                    onActivateSession: activateSession,
                    onActivateHostedSession: activateHostedSession,
                    onCloseSession: closeSession,
                    onCloseOthers: closeOtherSessions,
                    onTogglePinned: togglePinned,
                    onMoveSessionToGroup: moveSessionToGroup,
                    onStartTabDrag: beginTabDrag,
                    onDropTabBefore: dropDraggedTab(before:in:)
                )
            }
        }
    }

    // MARK: - Editor Content

    /// 编辑器主体（Phase 3: session 驱动，不再依赖 .id(fileURL) 重建）
    @ViewBuilder
    private var editorContent: some View {
        if state.isMarkdownFile {
            if state.isMarkdownPreviewMode {
                // Markdown 预览模式
                markdownPreviewContent
            } else {
                // 源码模式
                sourceEditorContent
            }
        } else if state.canPreview {
            sourceEditorContent
        } else if state.isBinaryFile, let fileURL = state.currentFileURL {
            // 二进制/非文本文件预览
            FilePreviewView(fileURL: fileURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if projectVM.isFileSelected {
            unsupportedFileView
        }
    }

    /// 源码编辑器（Phase 3: 基于 session 驱动）
    @ViewBuilder
    private var sourceEditorContent: some View {
        // 关键改进：不再使用 .id(state.currentFileURL) 强制重建编辑器实例
        // 编辑器现在是稳定的容器，内容由 session 切换驱动
        SourceEditorView(state: state)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    /// Markdown 渲染预览（内联替换编辑器）
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
            // Banner 也需要覆盖下层内容
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
            return String(localized: "项目语义上下文未就绪，跨文件语义能力可能不稳定。", table: "LumiEditor")
        default:
            break
        }
        guard state.currentFileURL != nil else { return nil }
        if !snapshot.currentFileIsInTarget {
            return String(localized: "当前文件未绑定到任何编译 target，跨文件跳转和诊断可能不可用。", table: "LumiEditor")
        }
        if let activeScheme = snapshot.activeScheme,
           let currentTarget = snapshot.currentFilePrimaryTarget,
           !currentTarget.isEmpty,
           !snapshot.activeSchemeBuildableTargets.isEmpty,
           !snapshot.activeSchemeBuildableTargets.contains(currentTarget) {
            return String(localized: "当前文件属于 target '\(currentTarget)'，但当前 scheme '\(activeScheme)' 可能没有覆盖它。", table: "LumiEditor")
        }
        if snapshot.currentFileMatchedTargets.count > 1 {
            if let preferredTarget = snapshot.currentFilePrimaryTarget, !preferredTarget.isEmpty {
                return String(localized: "当前文件属于多个 target，编辑器当前按 '\(preferredTarget)' 的语义上下文解析。", table: "LumiEditor")
            }
            let targets = snapshot.currentFileMatchedTargets.joined(separator: ", ")
            return String(localized: "当前文件同时属于多个 target（\(targets)），语义结果会受当前 scheme/configuration 影响。", table: "LumiEditor")
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
                        title: String(localized: "编辑器设置", table: "LumiEditor"),
                        subtitle: String(localized: "Adjust font size, tab size, line wrapping, minimap, and save behavior.", table: "LumiEditor"),
                        systemImage: "slider.horizontal.3",
                        accent: AppUI.Color.semantic.warning,
                        action: openEditorSettings
                    )
                }

                discoverabilitySection(
                    title: String(localized: "常用起点", table: "LumiEditor"),
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
                    title: String(localized: "Workbench 能力", table: "LumiEditor"),
                    subtitle: String(localized: "These capabilities align most closely with the editor surface in VS Code.", table: "LumiEditor")
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        capabilityCard(
                            title: String(localized: "Split Editor", table: "LumiEditor"),
                            subtitle: String(localized: "Split right or down — ideal for side-by-side reading and multi-file editing.", table: "LumiEditor"),
                            systemImage: "rectangle.split.2x1",
                            shortcut: "⌘\\",
                            action: { NotificationCenter.postLumiEditorSplitRight() }
                        )
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
                            subtitle: String(localized: "Tabs, splits, recently closed recovery, and back-forward navigation preserve workbench state.", table: "LumiEditor"),
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
                    quickHintChip(String(localized: "Restore sessions and split workbench state", table: "LumiEditor"))
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

    // MARK: - Session Management

    private func openOrActivateSession(for fileURL: URL?) {
        state.projectRootPath = projectVM.currentProject?.path
        refreshProjectContext(for: projectVM.currentProjectPath)
        guard let session = sessionStore.openOrActivate(fileURL: fileURL) else {
            state.loadFile(from: nil)
            applySnapshot(EditorSession(), toHostState: hostStore.state(for: workbench.activeGroupID))
            return
        }

        state.loadFile(from: session.fileURL)
        applySnapshot(session, toHostState: hostStore.state(for: workbench.activeGroupID))
        restoreInteractionState(for: session)
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

    private func preferredHostedSnapshot(
        for groupID: EditorGroup.ID,
        sessionID: EditorSession.ID
    ) -> EditorSession? {
        let hostedSnapshot = hostStore.state(for: groupID).activeSession
        guard hostedSnapshot.id == sessionID else { return nil }
        return hostedSnapshot
    }

    private func resolvedPreferredSnapshot(
        sessionID: EditorSession.ID,
        preferredGroupID: EditorGroup.ID?,
        fallbackGroupID: EditorGroup.ID? = nil
    ) -> EditorSession? {
        if let preferredGroupID,
           let snapshot = preferredHostedSnapshot(for: preferredGroupID, sessionID: sessionID) {
            return snapshot
        }

        if let fallbackGroupID,
           fallbackGroupID != preferredGroupID,
           let snapshot = preferredHostedSnapshot(for: fallbackGroupID, sessionID: sessionID) {
            return snapshot
        }

        return nil
    }

    private func resolvedActivationSession(
        for groupID: EditorGroup.ID,
        fallback session: EditorSession
    ) -> SessionActivation? {
        resolvedSessionActivation(
            for: session.id,
            fallback: session,
            preferredGroupID: groupID
        )
    }

    private func resolvedSessionActivation(
        for sessionID: EditorSession.ID,
        preferredGroupID: EditorGroup.ID? = nil
    ) -> SessionActivation? {
        guard let session = sessionStore.session(for: sessionID) else { return nil }
        return resolvedSessionActivation(
            for: sessionID,
            fallback: session,
            preferredGroupID: preferredGroupID
        )
    }

    private func resolvedSessionActivation(
        for sessionID: EditorSession.ID,
        fallback session: EditorSession,
        preferredGroupID: EditorGroup.ID? = nil
    ) -> SessionActivation? {
        return resolvedActivation(
            for: session,
            preferredSnapshot: resolvedPreferredSnapshot(
                sessionID: sessionID,
                preferredGroupID: preferredGroupID
            )
        )
    }

    private func activateSession(_ tab: EditorTab) {
        activateSessionIntent(sessionID: tab.sessionID)
    }

    private func activateHostedSession(
        in groupID: EditorGroup.ID,
        _ tab: EditorTab
    ) {
        activateSessionIntent(
            sessionID: tab.sessionID,
            preferredGroupID: groupID
        )
    }

    private func activateOpenEditor(_ item: EditorOpenEditorItem) {
        activateSessionIntent(
            sessionID: item.sessionID,
            preferredGroupID: item.groupID
        )
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

    private func activateSessionIntent(
        sessionID: EditorSession.ID,
        preferredGroupID: EditorGroup.ID? = nil
    ) {
        pendingActivationIntent = ActivationIntent(
            preferredGroupID: preferredGroupID,
            sessionID: sessionID
        )
        activateSessionID(sessionID, preferredGroupID: preferredGroupID)
    }

    private func activateSessionID(
        _ sessionID: EditorSession.ID,
        preferredGroupID: EditorGroup.ID? = nil
    ) {
        guard let resolved = resolvedSessionActivation(
            for: sessionID,
            preferredGroupID: preferredGroupID
        ) else {
            print("[TabSwitch] ❌ resolvedSessionActivation returned nil for sessionID=\(sessionID)")
            return
        }
        if resolved.sessionID == sessionStore.activeSessionID && projectVM.selectedFileURL == resolved.fileURL {
            print("[TabSwitch] ⚠️ Guard blocked: sessionID=\(resolved.sessionID) == activeSessionID=\(sessionStore.activeSessionID), fileURL=\(resolved.fileURL) == selectedFileURL=\(String(describing: projectVM.selectedFileURL))")
            return
        }
        print("[TabSwitch] ✅ Activating sessionID=\(resolved.sessionID), fileURL=\(resolved.fileURL), currentActive=\(String(describing: sessionStore.activeSessionID))")
        applyResolvedSessionActivation(resolved)
    }

    private func consumePendingActivationIntent(for groupID: EditorGroup.ID) -> Bool {
        guard let pendingActivationIntent,
              pendingActivationIntent.preferredGroupID == groupID else {
            return false
        }
        return true
    }

    private func resolvedActivation(
        for session: EditorSession,
        preferredSnapshot: EditorSession? = nil
    ) -> SessionActivation? {
        guard let fileURL = session.fileURL else { return nil }
        let activationSnapshot = resolvedSnapshot(
            for: session,
            preferredSnapshot
        )
        return SessionActivation(
            sessionID: session.id,
            fileURL: fileURL,
            snapshot: activationSnapshot
        )
    }

    private func resolvedSnapshot(
        for session: EditorSession,
        _ preferredSnapshot: EditorSession?,
    ) -> EditorSession {
        guard let fileURL = session.fileURL,
              let preferredSnapshot,
              preferredSnapshot.fileURL == fileURL else { return session }
        return preferredSnapshot
    }

    private func performSessionActivation(
        sessionID: EditorSession.ID,
        fileURL: URL,
        snapshot: EditorSession
    ) {
        _ = sessionStore.activate(sessionID: sessionID)
        _ = workbench.activate(sessionID: sessionID)
        applyActivatedEditorState(fileURL: fileURL, snapshot: snapshot)
    }

    private func closeSession(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID) else { return }
        let wasActive = session.id == sessionStore.activeSessionID
        let nextGroupSession = workbench.close(sessionID: session.id)
        if wasActive, state.hasUnsavedChanges {
            state.saveNow()
        }

        let nextSession = sessionStore.close(sessionID: session.id)
        guard wasActive else {
            if nextGroupSession != nil {
                syncEditorToActiveGroup()
            }
            return
        }

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

        let _ = workbench.closeOthers(keeping: session.id)
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
        applySnapshot(session, toSessionID: session.id)
        restoreInteractionState(for: session)
    }

    private func navigateForward() {
        guard let session = sessionStore.goForward(),
              let fileURL = session.fileURL else { return }
        projectVM.selectFile(at: fileURL)
        applySnapshot(session, toSessionID: session.id)
        restoreInteractionState(for: session)
    }

    private func togglePinned(_ tab: EditorTab) {
        sessionStore.togglePinned(sessionID: tab.sessionID)
        workbench.groupContainingSession(sessionID: tab.sessionID)?.togglePinned(sessionID: tab.sessionID)
    }

    private func beginTabDrag(_ tab: EditorTab) {
        draggedTabSessionID = tab.sessionID
    }

    private func dropDraggedTabInActiveStrip(before targetTab: EditorTab?) {
        guard let activeGroup = workbench.activeGroup else {
            draggedTabSessionID = nil
            return
        }
        dropDraggedTab(before: targetTab, in: activeGroup.id)
    }

    private func dropDraggedTab(before targetTab: EditorTab?, in groupID: EditorGroup.ID) {
        guard let draggedTabSessionID else { return }
        defer { self.draggedTabSessionID = nil }

        if targetTab?.sessionID == draggedTabSessionID {
            return
        }

        let sourceGroupID = workbench.groupContainingSession(sessionID: draggedTabSessionID)?.id
        let targetSessionID = targetTab?.sessionID
        let sourceSnapshot = sourceSnapshotForDraggedSession(draggedTabSessionID)

        if sourceGroupID == groupID {
            guard workbench.reorderSession(
                sessionID: draggedTabSessionID,
                in: groupID,
                before: targetSessionID
            ) else { return }
            _ = sessionStore.reorderSession(
                sessionID: draggedTabSessionID,
                before: targetSessionID
            )
            return
        }

        guard workbench.moveSession(
            sessionID: draggedTabSessionID,
            toGroupID: groupID,
            before: targetSessionID
        ) else { return }
        workbench.activateGroup(groupID)

        if let targetSessionID {
            _ = sessionStore.reorderSession(
                sessionID: draggedTabSessionID,
                before: targetSessionID
            )
        } else {
            _ = sessionStore.reorderSession(
                sessionID: draggedTabSessionID,
                before: nil
            )
        }

        if let sourceSnapshot {
            syncGroupHost(groupID, from: sourceSnapshot, seedSession: true)
        }
        syncEditorToActiveGroup()
    }

    private func sourceSnapshotForDraggedSession(_ sessionID: EditorSession.ID) -> EditorSession? {
        if sessionID == state.activeSession.id, state.activeSession.fileURL != nil {
            return state.activeSession
        }
        return sessionStore.session(for: sessionID)
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

    // MARK: - Split Editor (Phase 4)

    /// 分割当前编辑器
    func splitEditor(_ direction: EditorGroup.SplitDirection) {
        let sourceSnapshot = state.activeSession
        workbench.splitActiveGroup(direction)
        if let targetGroup = workbench.activeGroup {
            syncGroupHost(targetGroup.id, from: sourceSnapshot, seedSession: true)
        }
        syncEditorToActiveGroup()
    }

    /// 取消分割
    func unsplitEditor() {
        workbench.unsplitActiveGroup()
        syncEditorToActiveGroup()
    }

    /// 将当前 session 移动到另一个 group
    func moveSessionToGroup(groupID: EditorGroup.ID) {
        let sourceSnapshot = state.activeSession
        guard workbench.moveActiveSessionTo(groupID: groupID) else { return }
        syncGroupHost(groupID, from: sourceSnapshot, seedSession: true)
        syncEditorToActiveGroup()
    }

    private func focusNextGroup() {
        guard workbench.focusNextGroup() != nil else { return }
        syncEditorToActiveGroup()
    }

    private func focusPreviousGroup() {
        guard workbench.focusPreviousGroup() != nil else { return }
        syncEditorToActiveGroup()
    }

    private func moveActiveSessionToNextGroup() {
        let sourceSnapshot = state.activeSession
        let targetGroupID = workbench.nextLeafGroup(after: workbench.activeGroupID)?.id
        guard workbench.moveActiveSessionToNextGroup() else { return }
        if let targetGroupID {
            syncGroupHost(targetGroupID, from: sourceSnapshot, seedSession: true)
        }
        syncEditorToActiveGroup()
    }

    private func moveActiveSessionToPreviousGroup() {
        let sourceSnapshot = state.activeSession
        let targetGroupID = workbench.previousLeafGroup(before: workbench.activeGroupID)?.id
        guard workbench.moveActiveSessionToPreviousGroup() else { return }
        if let targetGroupID {
            syncGroupHost(targetGroupID, from: sourceSnapshot, seedSession: true)
        }
        syncEditorToActiveGroup()
    }

    private func syncEditorToActiveGroup() {
        guard let activeGroup = workbench.activeGroup,
              let activeSession = activeGroup.activeSession else { return }

        // 主 EditorState 需要同步到活跃 group 的文件和交互状态，
        // 以便 toolbar、状态栏、命令面板等正确反映当前活跃分栏。
        let hostedState = hostStore.state(for: activeGroup.id)
        syncPrimaryStateFromHosted(hostedState, session: activeSession)
    }

    /// 将活跃 group 的 hosted state 同步到主 EditorState。
    ///
    /// 这样 toolbar、状态栏、命令面板、面板等都读取主 state 的值，
    /// 确保它们反映当前活跃分栏的状态。
    private func syncPrimaryStateFromHosted(_ hostedState: EditorState, session: EditorSession) {
        // 同步文件内容状态
        if hostedState.currentFileURL != state.currentFileURL {
            // hosted state 已经加载了目标文件，直接同步内容引用
            if hostedState.content != nil {
                state.loadFile(from: hostedState.currentFileURL)
            } else {
                state.loadFile(from: session.fileURL)
            }
        }

        // 同步交互状态（光标、滚动、选区、查找等）
        let snapshot = hostedState.activeSession
        if snapshot.fileURL != nil {
            restoreInteractionState(for: snapshot)
        } else {
            restoreInteractionState(for: session)
        }
    }

    private func syncGroupHost(
        _ groupID: EditorGroup.ID,
        from snapshot: EditorSession,
        seedSession: Bool = false
    ) {
        applySnapshot(
            snapshot,
            toGroupID: groupID,
            seedSession: seedSession,
            hostState: hostStore.state(for: groupID)
        )
    }

    private func applySnapshot(_ snapshot: EditorSession, toHostState hostState: EditorState) {
        applySnapshot(
            snapshot: snapshot,
            toEditorState: hostState,
            projectRootPath: state.projectRootPath,
            requireFocusedTextView: false
        )
    }

    private func applyResolvedSnapshot(
        _ snapshot: EditorSession,
        preferredGroupID: EditorGroup.ID,
        toHostState hostState: EditorState
    ) {
        let resolvedSnapshot = resolvedPreferredSnapshot(
            sessionID: snapshot.id,
            preferredGroupID: preferredGroupID
        ) ?? snapshot
        applySnapshot(resolvedSnapshot, toHostState: hostState)
    }

    private func applySnapshot(
        _ snapshot: EditorSession,
        toGroupID groupID: EditorGroup.ID,
        seedSession: Bool,
        hostState: EditorState
    ) {
        guard let targetGroup = workbench.findGroup(id: groupID) else { return }

        if seedSession, let targetSession = targetGroup.activeSession {
            applySnapshot(snapshot, toSession: targetSession)
        }

        applyResolvedSnapshot(
            snapshot,
            preferredGroupID: groupID,
            toHostState: hostState
        )
    }

    private func applyResolvedSessionActivation(_ activation: SessionActivation) {
        if pendingActivationIntent?.sessionID == activation.sessionID {
            pendingActivationIntent = nil
        }
        applySnapshot(activation.snapshot, toSessionID: activation.sessionID)
        performSessionActivation(
            sessionID: activation.sessionID,
            fileURL: activation.fileURL,
            snapshot: activation.snapshot
        )
    }

    private func applyActivatedEditorState(fileURL: URL, snapshot: EditorSession) {
        if projectVM.selectedFileURL != fileURL {
            projectVM.selectFile(at: fileURL)
        } else {
            restoreInteractionState(for: snapshot)
        }
    }

    private func applySnapshot(_ snapshot: EditorSession, toSessionID sessionID: EditorSession.ID) {
        if let session = sessionStore.session(for: sessionID) {
            applySnapshot(snapshot, toSession: session)
        }
        if let session = workbench.groupContainingSession(sessionID: sessionID)?
            .session(for: sessionID) {
            applySnapshot(snapshot, toSession: session)
        }
    }

    private func applySnapshot(_ snapshot: EditorSession, toSession session: EditorSession) {
        session.applySnapshot(from: snapshot)
    }

    private func applySnapshot(
        snapshot: EditorSession,
        toEditorState targetState: EditorState,
        projectRootPath: String?,
        requireFocusedTextView: Bool
    ) {
        var restoreToken: AnyCancellable?
        EditorStateRestoreCoordinator.apply(
            snapshot: snapshot,
            to: targetState,
            projectRootPath: projectRootPath,
            requireFocusedTextView: requireFocusedTextView,
            restoreToken: &restoreToken
        )
    }

    /// 恢复交互状态
    private func restoreInteractionState(for session: EditorSession) {
        applySnapshot(
            snapshot: session,
            toEditorState: state,
            projectRootPath: state.projectRootPath,
            requireFocusedTextView: true
        )
    }

}

// MARK: - Editor Group View (Phase 4)

/// 递归渲染编辑器分栏组
struct EditorGroupView: View {
    @ObservedObject var group: EditorGroup
    @ObservedObject var workbench: EditorWorkbenchState
    @ObservedObject var editorState: EditorState
    @ObservedObject var hostStore: EditorGroupHostStore
    @EnvironmentObject private var themeManager: ThemeManager
    let onActivateSession: (EditorTab) -> Void
    let onActivateHostedSession: (EditorGroup.ID, EditorTab) -> Void
    let onCloseSession: (EditorTab) -> Void
    let onCloseOthers: (EditorTab) -> Void
    let onTogglePinned: (EditorTab) -> Void
    let onMoveSessionToGroup: (EditorGroup.ID) -> Void
    let onStartTabDrag: (EditorTab) -> Void
    let onDropTabBefore: (EditorTab?, EditorGroup.ID) -> Void

    var body: some View {
        if group.isLeaf {
            // 叶子 group：渲染编辑器
            leafGroupContent
        } else {
            // 非叶子 group：渲染子 group
            splitGroupContent
        }
    }

    @ViewBuilder
    private var leafGroupContent: some View {
        let isActiveGroup = workbench.activeGroupID == group.id
        VStack(spacing: 0) {
            leafGroupHeader
            if let activeSession = group.activeSession,
               activeSession.fileURL != nil {
                editorContent(for: activeSession, isActiveGroup: isActiveGroup)
            } else {
                emptyPlaceholder
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(
                    workbench.activeGroupID == group.id
                        ? AppUI.Color.semantic.warning.opacity(0.45)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            workbench.activateGroup(group.id)
        }
        .onDrop(of: [.plainText], isTargeted: nil) { _ in
            onDropTabBefore(nil, group.id)
            return true
        }
    }

    @ViewBuilder
    private var splitGroupContent: some View {
        let subGroups = group.subGroups
        if subGroups.isEmpty {
            emptyPlaceholder
        } else if group.splitDirection == .horizontal {
            HStack(spacing: 1) {
                ForEach(Array(subGroups.enumerated()), id: \.element.id) { _, subGroup in
                    EditorGroupView(
                        group: subGroup,
                        workbench: workbench,
                        editorState: editorState,
                        hostStore: hostStore,
                        onActivateSession: onActivateSession,
                        onActivateHostedSession: onActivateHostedSession,
                        onCloseSession: onCloseSession,
                        onCloseOthers: onCloseOthers,
                        onTogglePinned: onTogglePinned,
                        onMoveSessionToGroup: onMoveSessionToGroup,
                        onStartTabDrag: onStartTabDrag,
                        onDropTabBefore: onDropTabBefore
                    )
                }
            }
        } else {
            VStack(spacing: 1) {
                ForEach(Array(subGroups.enumerated()), id: \.element.id) { _, subGroup in
                    EditorGroupView(
                        group: subGroup,
                        workbench: workbench,
                        editorState: editorState,
                        hostStore: hostStore,
                        onActivateSession: onActivateSession,
                        onActivateHostedSession: onActivateHostedSession,
                        onCloseSession: onCloseSession,
                        onCloseOthers: onCloseOthers,
                        onTogglePinned: onTogglePinned,
                        onMoveSessionToGroup: onMoveSessionToGroup,
                        onStartTabDrag: onStartTabDrag,
                        onDropTabBefore: onDropTabBefore
                    )
                }
            }
        }
    }

    private var leafGroupHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(String(localized: "Group \(groupOrdinal)", table: "LumiEditor"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)

                Spacer(minLength: 0)

                if workbench.leafGroups.count > 1, group.activeSessionID != nil {
                    Menu {
                        ForEach(workbench.leafGroups.filter { $0.id != group.id }) { targetGroup in
                            Button(String(localized: "Move To Group \(leafOrdinal(for: targetGroup))", table: "LumiEditor")) {
                                workbench.activateGroup(group.id)
                                onMoveSessionToGroup(targetGroup.id)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.right.square")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppUI.Color.semantic.textTertiary)
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            if !group.tabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(group.tabs) { tab in
                            groupTabItem(for: tab)
                        }
                    }
                    .onDrop(of: [.plainText], isTargeted: nil) { _ in
                        onDropTabBefore(nil, group.id)
                        return true
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeManager.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
            Text(String(localized: "No file open", table: "LumiEditor"))
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func editorContent(for session: EditorSession, isActiveGroup: Bool) -> some View {
        if session.fileURL != nil {
            // 统一使用 hosted state：每个 group（无论是否活跃）使用独立的 EditorState
            EditorGroupHostView(
                session: session,
                projectRootPath: editorState.projectRootPath,
                state: hostStore.state(for: group.id),
                onActivate: {
                    workbench.activateGroup(group.id)
                    if let tab = group.tabs.first(where: { $0.sessionID == session.id }) {
                        onActivateHostedSession(group.id, tab)
                    }
                }
            )
        }
    }

    private func groupTabItem(for tab: EditorTab) -> some View {
        let isActive = tab.sessionID == group.activeSessionID

        return HStack(spacing: 6) {
            Circle()
                .fill(tab.isDirty ? AppUI.Color.semantic.warning : AppUI.Color.semantic.textTertiary.opacity(0.35))
                .frame(width: 5, height: 5)

            if tab.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 7))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }

            Text(tab.title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? AppUI.Color.semantic.textPrimary : AppUI.Color.semantic.textSecondary)
                .lineLimit(1)

            Button {
                onCloseSession(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? AppUI.Color.semantic.textPrimary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            workbench.activateGroup(group.id)
            onActivateHostedSession(group.id, tab)
        }
        .onDrag {
            onStartTabDrag(tab)
            return NSItemProvider(object: tab.sessionID.uuidString as NSString)
        } preview: {
            if let fileURL = tab.fileURL {
                DragPreview(fileURL: fileURL)
            } else {
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.95))
                    )
            }
        }
        .onDrop(of: [.plainText], isTargeted: nil) { _ in
            onDropTabBefore(tab, group.id)
            return true
        }
        .contextMenu {
            Button(
                tab.isPinned
                    ? String(localized: "Unpin Tab", table: "LumiEditor")
                    : String(localized: "Pin Tab", table: "LumiEditor")
            ) {
                onTogglePinned(tab)
            }
            Button(String(localized: "Close Others", table: "LumiEditor")) {
                onCloseOthers(tab)
            }
        }
    }

    private var groupOrdinal: Int {
        leafOrdinal(for: group)
    }

    private func leafOrdinal(for targetGroup: EditorGroup) -> Int {
        (workbench.leafGroups.firstIndex(where: { $0.id == targetGroup.id }) ?? 0) + 1
    }
}

/// 每个 split 分栏的编辑器宿主视图。
///
/// 每个分栏持有独立的 `EditorState`，可以独立加载文件、编辑、保存。
/// 点击激活时通知父视图切换活跃 group。
private struct EditorGroupHostView: View {
    private struct RestoreTrigger: Equatable {
        let sessionID: EditorSession.ID
        let fileURL: URL?
        let isDirty: Bool
        let projectRootPath: String?
    }

    @ObservedObject var session: EditorSession
    let projectRootPath: String?
    @ObservedObject var state: EditorState
    let onActivate: () -> Void
    @State private var restoreToken: AnyCancellable?
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            Group {
                if state.isMarkdownFile, state.isMarkdownPreviewMode {
                    ScrollView {
                        if let content = state.content?.string, !content.isEmpty {
                            MarkdownBlockRenderer(markdown: content)
                                .padding(20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.activeAppTheme.workspaceBackgroundColor())
                } else if state.canPreview || state.isBinaryFile {
                    SourceEditorView(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.system(size: 24))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                        Text(session.fileURL?.lastPathComponent ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onActivate)
        }
        .task(id: restoreTrigger) {
            applyHostedSnapshot()
        }
        .onReceive(session.objectWillChange) { _ in
            DispatchQueue.main.async {
                applyHostedSnapshot()
            }
        }
    }

    private var restoreTrigger: RestoreTrigger {
        RestoreTrigger(
            sessionID: session.id,
            fileURL: session.fileURL,
            isDirty: session.isDirty,
            projectRootPath: projectRootPath
        )
    }

    private func applyHostedSnapshot() {
        EditorStateRestoreCoordinator.apply(
            snapshot: session,
            to: state,
            projectRootPath: projectRootPath,
            requireFocusedTextView: false,
            restoreToken: &restoreToken
        )
    }
}

@MainActor
private enum EditorStateRestoreCoordinator {
    static func apply(
        snapshot: EditorSession,
        to state: EditorState,
        projectRootPath: String?,
        requireFocusedTextView: Bool,
        restoreToken: inout AnyCancellable?
    ) {
        state.projectRootPath = projectRootPath

        guard let fileURL = snapshot.fileURL else {
            restoreToken?.cancel()
            restoreToken = nil
            state.loadFile(from: nil)
            return
        }

        let canRestoreImmediately =
            state.currentFileURL == fileURL &&
            state.content != nil &&
            (!requireFocusedTextView || state.focusedTextView != nil)

        if canRestoreImmediately {
            state.applySessionRestore(snapshot)
            return
        }

        restoreToken?.cancel()
        if state.currentFileURL != fileURL {
            state.loadFile(from: fileURL)
        }

        var pendingRestoreToken: AnyCancellable?
        pendingRestoreToken = state.$activeSession
            .dropFirst()
            .first(where: { _ in true })
            .sink { [weak state] _ in
                guard let state else { return }
                if state.currentFileURL == snapshot.fileURL,
                   state.content != nil,
                   (!requireFocusedTextView || state.focusedTextView != nil) {
                    DispatchQueue.main.async {
                        state.applySessionRestore(snapshot)
                    }
                }
                pendingRestoreToken?.cancel()
                pendingRestoreToken = nil
            }
        restoreToken = pendingRestoreToken
    }
}

// MARK: - Preview

#Preview {
    EditorPanelView()
        .inRootView()
}
