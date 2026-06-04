import CodeEditSourceEditor
import Combine
import EditorService
import FilePreviewKit
import LumiCoreKit
import MarkdownKit
import SwiftUI
import LumiUI
import UniformTypeIdentifiers

/// 编辑器主视图
///
/// 纯布局职责：组合编辑器内容区域、Banner、Sheet 等 UI 组件。
/// 所有业务逻辑委托给 `EditorPanelService`，生命周期和事件路由由 `EditorPanelCoordinator` 管理。
public struct EditorPanelView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var service: EditorService

    /// 便利访问
    private var editorState: EditorState { service.state }

    /// 面板业务逻辑
    @StateObject private var panelService = EditorPanelService()

    /// 生命周期与事件路由协调器
    @StateObject private var coordinator = EditorPanelCoordinator()

    /// 标记编辑器协调器是否已完成初始化
    /// 避免在 SourceEditorView.onAppear (initializeCoordinators) 执行前就触发文件加载导致崩溃
    @State private var isEditorReady: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            if hasActiveEditorSelection {
                FileInfoBannerView(
                    service: service,
                    warningMessage: panelService.projectContextWarningMessage(service: service)
                )
                editorContent
            } else {
                EditorEmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
            coordinator.handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onChange(of: service.currentFileURL) {
            coordinator.handleCurrentFileURLChange()
        }
        .onChange(of: service.cursorLine) {
            coordinator.handleCursorLineChange()
        }
        .onChange(of: service.documentSymbolProvider.symbols.map(\.id)) {
            coordinator.handleDocumentSymbolsChange()
        }
        .onAppear {
            coordinator.configure(
                panelService: panelService,
                service: service,
                projectVM: projectVM
            )
            coordinator.handleAppear()
        }
        .onDisappear {
            coordinator.handleDisappear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .applicationDidResignActive)) { _ in
            coordinator.handleApplicationDidResignActive()
        }
        .onReceive(coordinator.subscribeEditorCommands(isCommandPalettePresented: $panelService.isCommandPalettePresented)) { event in
            coordinator.handleCommandEvent(event)
        }
        .background(editorSheetHosts)
    }

    // MARK: - Sheet Hosts

    private var editorSheetHosts: some View {
        let sheets = builtinSheets + service.editorExtensions.sheetSuggestions(state: service.state).filter {
            $0.id != "builtin.workspace-symbol-sheet" &&
                $0.id != "builtin.call-hierarchy-sheet"
        }
        return ZStack {
            ForEach(sheets) { sheet in
                EmptyView()
                    .sheet(
                        isPresented: Binding(
                            get: { sheet.isPresented(service.state) },
                            set: { presented in
                                if !presented {
                                    sheet.onDismiss(service.state)
                                }
                            }
                        )
                    ) {
                        sheet.content(service.state)
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
                            openEditors: panelService.openEditorItems(service),
                            onOpenFile: { url, target, highlightLine in
                                panelService.openFileFromQuickOpen(
                                    url,
                                    target: target,
                                    highlightLine: highlightLine,
                                    service: service,
                                    projectRootPath: self.projectVM.currentProject?.path,
                                    currentProjectPath: self.projectVM.currentProjectPath
                                )
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
        hasActiveEditorSelection && service.isFileLoadInProgress
    }

    /// 编辑器是否存在激活会话（以 Editor 内核作为当前文件真源）
    private var hasActiveEditorSelection: Bool {
        service.activeSessionID != nil || service.currentFileURL != nil
    }

    /// 编辑器主体（session 驱动）
    @ViewBuilder
    private var editorContent: some View {
        if service.isMarkdownFile {
            if service.isMarkdownPreviewMode {
                markdownPreviewContent
            } else {
                sourceEditorContent
            }
        } else if service.canPreview {
            sourceEditorContent
        } else if service.isBinaryFile, let fileURL = service.currentFileURL {
            FilePreviewView(fileURL: fileURL).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isFileLoading {
            EditorLoadingStateView()
        } else if let message = service.fileLoadErrorMessage, hasActiveEditorSelection {
            EditorLoadFailureView(fileName: service.activeSession?.fileURL?.lastPathComponent ?? service.fileName, message: message)
        } else if hasActiveEditorSelection {
            EditorUnsupportedFileView(fileName: service.fileName)
        }
    }

    @ViewBuilder
    private var sourceEditorContent: some View {
        SourceEditorView(state: service.state)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipped()
    }

    @ViewBuilder
    private var markdownPreviewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let content = service.content?.string, !content.isEmpty {
                    MarkdownBlockRenderer(markdown: content)
                        .padding(20)
                } else {
                    Text(String(localized: "No content to preview", bundle: .module))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "98989E"))
                        .padding(40)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

}

// MARK: - Preview

#Preview {
    EditorPanelView()
        .inRootView()
}
