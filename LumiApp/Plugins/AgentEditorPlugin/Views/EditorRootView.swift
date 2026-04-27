import MagicKit
import SwiftUI

/// 编辑器主视图（根入口）
/// 组合面包屑、工具栏、编辑器、状态栏
struct EditorRootView: View {

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    /// 编辑器状态
    @StateObject private var state = EditorState()
    @StateObject private var sessionStore = EditorSessionStore()

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if projectVM.isFileSelected {
                    // Header 区域：面包屑 + 工具栏（带背景，覆盖编辑器）
                    headerArea

                    // 文件信息提示
                    fileInfoBanner

                    // 编辑器主体
                    editorContent
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

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        if state.isMarkdownFile {
            if state.isMarkdownPreviewMode {
                // Markdown 预览模式
                markdownPreviewContent
            } else {
                // 源码模式
                SourceEditorView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(state.currentFileURL)
                    .clipped()
            }
        } else if state.canPreview {
            SourceEditorView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(state.currentFileURL)  // 文件切换时重建编辑器
                // 关键：裁剪溢出的内容，防止行号延伸到 header
                .clipped()
        } else if state.isBinaryFile, let fileURL = state.currentFileURL {
            // 二进制/非文本文件预览
            FilePreviewView(fileURL: fileURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if projectVM.isFileSelected {
            unsupportedFileView
        }
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

    private func restoreInteractionState(for session: EditorSession) {
        guard session.fileURL != nil else { return }
        Task { @MainActor in
            for _ in 0..<30 {
                if state.currentFileURL == session.fileURL, state.content != nil, state.focusedTextView != nil {
                    state.applySessionRestore(session)
                    return
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

}

// MARK: - Preview

#Preview {
    EditorRootView()
        .inRootView()
}
