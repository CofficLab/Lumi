#if canImport(LumiPreviewKit)
import AppKit
import LumiPreviewKit
import SwiftUI

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
        .onAppear {
            refreshScanAndStartIfNeeded()
        }
        .onDisappear {
            viewModel.liveCanvasDidDisappear()
        }
        .onChange(of: currentFileURL) { _, _ in
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: contentRevision) { _, _ in
            viewModel.sourceDidChange(sourceText: sourceText, fileURL: currentFileURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            viewModel.lumiWindowDidResignKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.lumiWindowDidBecomeKey()
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
                    selectedPreviewID: $viewModel.selectedPreviewID
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
                previewHeader(preview)

                if case .failed(let message) = viewModel.runState {
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

    private func previewHeader(_ preview: PreviewDiscovery) -> some View {
        HStack(spacing: 8) {
            Text(preview.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let primaryTypeName = preview.primaryTypeName {
                Label(primaryTypeName, systemImage: "swift")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)
        }
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
#else
import SwiftUI

struct EditorPreviewContentView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
