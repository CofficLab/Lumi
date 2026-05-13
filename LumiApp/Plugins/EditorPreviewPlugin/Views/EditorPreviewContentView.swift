import AppKit
import LumiPreviewKit
import SwiftUI

/// 编辑器预览内容主视图。
///
/// 预览面板的核心入口，负责：
/// - 监听编辑器内容变更，触发源码扫描和预览刷新
/// - 管理窗口生命周期事件（活跃/非活跃/最小化）
/// - 展示工具栏、预览列表和详情区域
/// - 根据运行状态显示空状态、诊断错误或渲染表面
struct EditorPreviewContentView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorPreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    private var contentRevision: UInt64 {
        editorVM.service.contentRevision
    }

    private var saveRevision: UInt64 {
        editorVM.service.saveRevision
    }

    private var refreshSignal: LumiPreviewPackage.EditorPreviewRefreshSignal {
        LumiPreviewPackage.EditorPreviewRefreshSignal(
            fileURL: currentFileURL,
            contentRevision: contentRevision,
            saveRevision: saveRevision
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorPreviewToolbarView(
                viewModel: viewModel,
                currentFileURL: currentFileURL
            )
            Divider()
            content
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .background(
            EditorPreviewWindowLifecycleReporter(
                onWindowBecameActive: {
                    viewModel.previewWindowDidBecomeActive()
                },
                onWindowBecameInactive: {
                    viewModel.previewWindowDidBecomeInactive()
                },
                onWindowFrameChanged: {
                    EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
                },
                onWindowInteraction: {
                    viewModel.previewWindowDidBecomeActive()
                }
            )
        )
        .onAppear {
            refreshScanAndStartIfNeeded()
        }
        .onDisappear {
            viewModel.previewPanelDidDisappear()
        }
        .onChange(of: currentFileURL) { _, _ in
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: refreshSignal) { _, _ in
            viewModel.sourceDidChange(sourceText: sourceText, fileURL: currentFileURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            viewModel.lumiWindowDidResignKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.lumiWindowDidBecomeKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didHideNotification)) { _ in
            viewModel.lumiWindowDidMiniaturizeOrClose()
        }
        .onApplicationWillTerminate {
            viewModel.applicationWillTerminate()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.previews.isEmpty {
            EditorPreviewEmptyStateView()
        } else {
            HStack(spacing: 0) {
                EditorPreviewListView(
                    previews: viewModel.previews,
                    selectedPreviewID: viewModel.selectedPreviewID,
                    onSelectPreview: { previewID in
                        viewModel.selectPreview(id: previewID)
                    }
                )
                .frame(width: 240)
                Divider()
                previewDetail
            }
        }
    }

    private var previewDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = viewModel.selectedPreview {
                if viewModel.isShowingStaleLivePreview {
                    staleLivePreviewDetail(preview)
                } else if case let .failed(message) = viewModel.runState {
                    errorMessageView(message)
                } else if viewModel.runState == .hostMissing {
                    Text(String(localized: "Set LUMI_PREVIEW_HOST_EXECUTABLE or embed LumiPreviewHostApp in Contents/Helpers.", table: "EditorPreview"))
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                } else if let diagnostics = viewModel.diagnostics {
                    EditorPreviewDiagnosticsView(diagnostics: diagnostics)
                } else {
                    EditorPreviewSurfaceView(viewModel: viewModel, preview: preview)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func staleLivePreviewDetail(_ preview: LumiPreviewPackage.PreviewDiscovery) -> some View {
        if case let .failed(message) = viewModel.runState {
            errorMessageView(message)
        } else if let renderMessage = viewModel.renderMessage {
            errorMessageView(renderMessage)
        }

        EditorPreviewSurfaceView(viewModel: viewModel, preview: preview)
    }

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshScan() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
    }

    private func refreshScanAndStartIfNeeded(allowsStopped: Bool = true) {
        refreshScan()
        viewModel.startSelectedPreviewIfNeeded(allowsStopped: allowsStopped)
    }
}
