import CodeEditSourceEditor
import Combine
import FilePreviewKit
import MagicKit
import MarkdownKit
import SwiftUI
import UniformTypeIdentifiers

/// 编辑器主视图
///
/// 纯布局职责：组合编辑器内容区域、Banner、Sheet 等 UI 组件。
/// 所有业务逻辑委托给 `EditorPanelService`，生命周期和事件路由由 `EditorPanelCoordinator` 管理。
struct EditorPanelView: View {
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var editorVM: EditorVM

    /// 便利访问
    private var service: EditorService { editorVM.service }
    private var state: EditorState { service.state }
    private var sessionStore: EditorSessionStore { service.sessionStore }

    /// 面板业务逻辑
    @StateObject private var panelService = EditorPanelService()

    /// 生命周期与事件路由协调器
    @StateObject private var coordinator = EditorPanelCoordinator()

    /// 标记编辑器协调器是否已完成初始化
    /// 避免在 SourceEditorView.onAppear (initializeCoordinators) 执行前就触发文件加载导致崩溃
    @State private var isEditorReady: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if projectVM.isFileSelected {
                fileInfoBanner
                editorContent
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            coordinator.handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onChange(of: projectVM.selectedFileURL) { _, newURL in
            coordinator.handleSelectedFileURLChange(newURL: newURL)
        }
        .onChange(of: state.currentFileURL) { _, _ in
            coordinator.handleCurrentFileURLChange()
        }
        .onChange(of: state.cursorLine) { _, _ in
            coordinator.handleCursorLineChange()
        }
        .onChange(of: state.documentSymbolProvider.symbols.map(\.id)) { _, _ in
            coordinator.handleDocumentSymbolsChange()
        }
        .onAppear {
            coordinator.configure(
                panelService: panelService,
                state: state,
                sessionStore: sessionStore,
                projectVM: projectVM
            )
            coordinator.handleAppear()
        }
        .onDisappear {
            coordinator.handleDisappear()
        }
        .onReceive(coordinator.subscribeEditorCommands(isCommandPalettePresented: $panelService.isCommandPalettePresented)) { event in
            coordinator.handleCommandEvent(event)
        }
        .background(editorSheetHosts)
    }

    // MARK: - Sheet Hosts

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
                isPresented: { _ in panelService.isCommandPalettePresented },
                onDismiss: { _ in panelService.isCommandPalettePresented = false },
                content: { state in
                    AnyView(
                        EditorCommandPaletteView(
                            state: state,
                            openEditors: panelService.openEditorItems(sessionStore),
                            onOpenFile: { url, target, highlightLine in
                                panelService.openFileFromQuickOpen(
                                    url,
                                    target: target,
                                    highlightLine: highlightLine,
                                    state: state,
                                    sessionStore: self.sessionStore,
                                    projectRootPath: self.projectVM.currentProject?.path,
                                    currentProjectPath: self.projectVM.currentProjectPath
                                ) { fileURL in
                                    self.projectVM.selectFile(at: fileURL)
                                }
                            }
                        ) {
                            panelService.isCommandPalettePresented = false
                        }
                    )
                }
            ),
        ]
    }

    // MARK: - Editor Content

    /// 文件是否正在加载中（已选中但 loadFile 异步 Task 尚未完成）
    private var isFileLoading: Bool {
        projectVM.isFileSelected && !state.canPreview && !state.isBinaryFile && state.currentFileURL == nil
    }

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
        } else if isFileLoading {
            loadingStateView
        } else if projectVM.isFileSelected {
            let _ = EditorPlugin.logger.warning("\(EditorPlugin.t)显示了「不支持的文件」视图. isMarkdownFile=\(state.isMarkdownFile), canPreview=\(state.canPreview), isBinaryFile=\(state.isBinaryFile), currentFileURL=\(state.currentFileURL?.path ?? "nil", privacy: .public), fileName=\(state.fileName, privacy: .public), fileExtension=\(state.fileExtension, privacy: .public), isFileSelected=\(projectVM.isFileSelected), selectedFileURL=\(projectVM.selectedFileURL?.path ?? "nil", privacy: .public)")
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
        let warningMessage = panelService.projectContextWarningMessage(state: state)
        if state.isTruncated || !state.isEditable || warningMessage != nil {
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
                if let warning = warningMessage {
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

    // MARK: - Empty State

    private var emptyState: some View {
        EditorEmptyStateView()
    }

    // MARK: - Loading State

    private var loadingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text(String(localized: "Loading...", table: "LumiEditor"))
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
}

// MARK: - Preview

#Preview {
    EditorPanelView()
        .inRootView()
}
