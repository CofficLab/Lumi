import MagicKit
import SwiftUI
import Combine

/// 编辑器主视图（根入口）
/// 组合面包屑、工具栏、编辑器、状态栏
///
/// Phase 4: 支持 workbench group 树，实现 split editor
struct EditorRootView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    /// 编辑器状态
    @StateObject private var state = EditorState()
    @StateObject private var sessionStore = EditorSessionStore()
    @StateObject private var workbench = EditorWorkbenchState()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if projectVM.isFileSelected {
                    // Header 区域：面包屑 + 工具栏（带背景，覆盖编辑器）
                    headerArea

                    // 文件信息提示
                    fileInfoBanner

                    // 编辑器主体（Phase 4: group 树渲染）
                    workbenchContent
                } else {
                    // 空状态
                    emptyState
                }
            }

            if let panel = activeSidePanel {
                panel.content(state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: projectVM.selectedFileURL) { _, newURL in
            openOrActivateSession(for: newURL)
        }
        .onAppear {
            // 初始加载
            state.projectRootPath = projectVM.currentProject?.path
            state.onActiveSessionChanged = { snapshot in
                sessionStore.syncActiveSession(from: snapshot)
                // 同步到 workbench
                workbench.syncActiveSession(from: snapshot)
            }
            if projectVM.isFileSelected {
                openOrActivateSession(for: projectVM.selectedFileURL)
            }
        }
        .onDisappear {
            // 切走时保存
            if state.hasUnsavedChanges {
                state.saveNow()
            }
            state.onActiveSessionChanged = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFormatDocument)) { _ in
            guard projectVM.isFileSelected else { return }
            state.performEditorCommand(id: "builtin.format-document")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorFindReferences)) { _ in
            guard projectVM.isFileSelected else { return }
            state.performEditorCommand(id: "builtin.find-references")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorRenameSymbol)) { _ in
            guard projectVM.isFileSelected else { return }
            state.performEditorCommand(id: "builtin.rename-symbol")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorWorkspaceSymbols)) { _ in
            guard projectVM.isFileSelected else { return }
            state.performEditorCommand(id: "builtin.workspace-symbols")
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiEditorCallHierarchy)) { _ in
            guard projectVM.isFileSelected else { return }
            state.performEditorCommand(id: "builtin.call-hierarchy")
        }
        .background(editorSheetHosts)
    }

    private var activeSidePanel: EditorSidePanelSuggestion? {
        state.editorExtensions
            .sidePanelSuggestions(state: state)
            .first(where: { $0.isPresented(state) })
    }

    private var editorSheetHosts: some View {
        let sheets = state.editorExtensions.sheetSuggestions(state: state)
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

    // MARK: - Header Area

    /// Header 区域：包含工具栏，带背景色覆盖编辑器内容
    private var headerArea: some View {
        VStack(spacing: 0) {
            if !sessionStore.sessions.isEmpty {
                EditorTabStripView(
                    tabs: sessionStore.tabs,
                    activeSessionID: sessionStore.activeSessionID,
                    canNavigateBack: sessionStore.canNavigateBack,
                    canNavigateForward: sessionStore.canNavigateForward,
                    onNavigateBack: navigateBack,
                    onNavigateForward: navigateForward,
                    onSelect: activateSession,
                    onClose: closeSession,
                    onCloseOthers: closeOtherSessions,
                    onTogglePinned: togglePinned
                )
            }

            EditorToolbarView(state: state)
        }
        // 关键：添加背景色，确保覆盖下方的编辑器内容（如行号）
        .background(
            Color(nsColor: .textBackgroundColor)
                .ignoresSafeArea()
        )
        // 使用 zIndex 确保 header 在编辑器上层
        .zIndex(1)
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
                    editorState: state
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
                    Text("No content to preview")
                        .font(.system(size: 12))
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .padding(40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - File Info Banner

    @ViewBuilder
    private var fileInfoBanner: some View {
        if state.isTruncated || !state.isEditable {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.warning.opacity(0.06))
            // Banner 也需要覆盖下层内容
            .background(Color(nsColor: .textBackgroundColor))
            .zIndex(1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(AppUI.Color.semantic.textTertiary)

            Text(String(localized: "Code Editor", table: "LumiEditor"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppUI.Color.semantic.textSecondary)

            Text(String(localized: "Select a file to start editing", table: "LumiEditor"))
                .font(.system(size: 12))
                .foregroundColor(AppUI.Color.semantic.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        guard let session = sessionStore.openOrActivate(fileURL: fileURL) else {
            state.loadFile(from: nil)
            return
        }

        state.loadFile(from: session.fileURL)
        restoreInteractionState(for: session)
    }

    private func activateSession(_ tab: EditorTab) {
        guard let session = sessionStore.session(for: tab.sessionID),
              let fileURL = session.fileURL else { return }
        guard session.id != sessionStore.activeSessionID || projectVM.selectedFileURL != fileURL else { return }
        _ = sessionStore.activate(sessionID: session.id)
        projectVM.selectFile(at: fileURL)
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
    }

    private func navigateForward() {
        guard let session = sessionStore.goForward(),
              let fileURL = session.fileURL else { return }
        projectVM.selectFile(at: fileURL)
    }

    private func togglePinned(_ tab: EditorTab) {
        sessionStore.togglePinned(sessionID: tab.sessionID)
    }

    // MARK: - Split Editor (Phase 4)

    /// 分割当前编辑器
    func splitEditor(_ direction: EditorGroup.SplitDirection) {
        workbench.splitActiveGroup(direction)
    }

    /// 取消分割
    func unsplitEditor() {
        workbench.unsplitActiveGroup()
    }

    /// 将当前 session 移动到另一个 group
    func moveSessionToGroup(groupID: EditorGroup.ID) {
        workbench.moveActiveSessionTo(groupID: groupID)
    }

    /// 恢复交互状态
    private func restoreInteractionState(for session: EditorSession) {
        guard session.fileURL != nil else { return }

        // 快速路径：如果编辑器已经加载了同一个文件，立即恢复
        if state.currentFileURL == session.fileURL,
           state.content != nil,
           state.focusedTextView != nil {
            state.applySessionRestore(session)
            return
        }

        // 加载新文件时，在 `onActiveSessionChanged` 回调中完成恢复
        // 这确保 content / textStorage / textView 都已就绪
        let sessionID = session.id
        var restoreToken: AnyCancellable?
        restoreToken = state.$activeSession
            .dropFirst()
            .first(where: { _ in true })  // 只要 activeSession 更新一次
            .sink { [weak state] _ in
                guard let state else { return }
                if state.currentFileURL == session.fileURL, state.content != nil {
                    // 再等一个 runloop 确保 textView 就绪
                    DispatchQueue.main.async {
                        if state.focusedTextView != nil {
                            state.applySessionRestore(session)
                        }
                    }
                }
                restoreToken?.cancel()
            }
    }

}

// MARK: - Editor Group View (Phase 4)

/// 递归渲染编辑器分栏组
struct EditorGroupView: View {
    @ObservedObject var group: EditorGroup
    @ObservedObject var workbench: EditorWorkbenchState
    @ObservedObject var editorState: EditorState

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
        VStack(spacing: 0) {
            if let activeSession = group.activeSession,
               let fileURL = activeSession.fileURL {
                editorContent(for: activeSession)
            } else {
                emptyPlaceholder
            }
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
                        editorState: editorState
                    )
                }
            }
        } else {
            VStack(spacing: 1) {
                ForEach(Array(subGroups.enumerated()), id: \.element.id) { _, subGroup in
                    EditorGroupView(
                        group: subGroup,
                        workbench: workbench,
                        editorState: editorState
                    )
                }
            }
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
    private func editorContent(for session: EditorSession) -> some View {
        if session.fileURL != nil {
            // 如果 session 对应的文件就是当前 state 的文件，直接显示
            if session.fileURL == editorState.currentFileURL {
                if editorState.isMarkdownFile, editorState.isMarkdownPreviewMode {
                    ScrollView {
                        if let content = editorState.content?.string, !content.isEmpty {
                            MarkdownBlockRenderer(markdown: content)
                                .padding(20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                } else if editorState.canPreview || editorState.isBinaryFile {
                    SourceEditorView(state: editorState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            } else {
                // 其他 session 的占位（Phase 4.5: 未来可实现多编辑器实例）
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
    }
}

// MARK: - Preview

#Preview {
    EditorRootView()
        .inRootView()
}
