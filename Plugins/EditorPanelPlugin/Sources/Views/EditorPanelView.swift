import Combine
import EditorService
import LumiCoreKit
import MarkdownKit
import SwiftUI
import LumiUI
import UniformTypeIdentifiers

/// 编辑器主视图
///
/// 组合编辑器内容区域、Banner、Sheet 等 UI 组件。
/// 所有业务逻辑委托给 `EditorPanelService`，生命周期和事件路由由 `EditorPanelCoordinator` 管理。
public struct EditorPanelView: View {
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var service: EditorService
    let lumiCore: any LumiCoreAccessing

    /// 便利访问
    private var editorState: EditorState { service.state }

    private var currentProjectPath: String {
        lumiCore.projectComponent.currentProject?.path ?? ""
    }

    private var projectRootPath: String? {
        let path = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    /// 面板业务逻辑
    @StateObject private var panelService = EditorPanelService()

    /// 生命周期与事件路由协调器
    @StateObject private var coordinator = EditorPanelCoordinator()

    /// 标记编辑器协调器是否已完成初始化
    /// 避免在 SourceEditorView.onAppear (initializeCoordinators) 执行前就触发文件加载导致崩溃
    @State private var isEditorReady: Bool = false

    public init(lumiCore: any LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    public var body: some View {
        VStack(spacing: 0) {
            if EditorPanelContentRouting.hasActiveEditorSelection(editorContentSnapshot) {
                FileInfoBannerView(
                    service: service
                )
                editorContent
            } else {
                EditorEmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .onChange(of: currentProjectPath) { oldPath, newPath in
            coordinator.handleProjectPathChange(oldPath: oldPath, newPath: newPath)
        }
        .onChange(of: service.files.currentFileURL) {
            coordinator.handleCurrentFileURLChange()
        }
        .onAppear {
            coordinator.configure(
                panelService: panelService,
                service: service
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
                                    projectRootPath: self.projectRootPath,
                                    currentProjectPath: self.currentProjectPath
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

    private var editorContentSnapshot: EditorPanelContentRouting.Snapshot {
        EditorPanelContentRouting.Snapshot(
            activeSessionID: service.sessions.activeSessionID,
            currentFileURL: service.files.currentFileURL,
            canPreview: service.files.canPreview,
            isBinaryFile: service.files.isBinaryFile,
            isFileLoadInProgress: service.files.isFileLoadInProgress,
            fileLoadErrorMessage: service.files.fileLoadErrorMessage,
            isMarkdownFile: service.files.isMarkdownFile,
            isMarkdownPreviewMode: service.isMarkdownPreviewMode
        )
    }

    /// 编辑器主体（session 驱动）
    @ViewBuilder
    private var editorContent: some View {
        switch EditorPanelContentRouting.resolve(editorContentSnapshot) {
        case .empty:
            EmptyView()
        case .loading:
            EditorLoadingStateView()
        case .sourceEditor:
            sourceEditorContent
        case .markdownPreview:
            markdownPreviewContent
        case .binaryPreview:
            if let fileURL = service.files.currentFileURL {
                FilePreviewView(fileURL: fileURL).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .loadFailure:
            if let message = service.files.fileLoadErrorMessage {
                EditorLoadFailureView(
                    fileName: service.sessions.activeSession?.fileURL?.lastPathComponent ?? service.files.fileName,
                    message: message
                )
            }
        case .unsupported:
            EditorUnsupportedFileView(fileName: service.files.fileName)
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
                if let content = service.files.content?.string, !content.isEmpty {
                    MarkdownBlockRenderer(markdown: content)
                        .padding(20)
                } else {
                    Text(LumiPluginLocalization.string("No content to preview", bundle: .module))
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

