import LumiPreviewKit
import SwiftUI

struct EditorRemoteHotPreviewDetailView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @StateObject private var viewModel = EditorRemoteHotPreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    private var refreshSignal: LumiPreviewPackage.EditorPreviewRefreshSignal {
        LumiPreviewPackage.EditorPreviewRefreshSignal(
            fileURL: currentFileURL,
            contentRevision: editorVM.service.contentRevision,
            saveRevision: editorVM.service.saveRevision
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HotPreviewToolbar(viewModel: viewModel)
            HStack(spacing: 0) {
                HotPreviewList(viewModel: viewModel)
                    .frame(width: 230)
                Divider()
                HotPreviewCanvas(viewModel: viewModel)
            }
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .background(
            EditorPreviewWindowLifecycleReporter(
                onWindowBecameActive: {
                    viewModel.previewWindowDidBecomeActive()
                },
                onWindowBecameInactive: {},
                onWindowFrameChanged: {
                    EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
                },
                onWindowInteraction: {
                    viewModel.previewWindowDidReceiveInteraction()
                }
            )
        )
        .onAppear {
            viewModel.viewDidAppear()
            refreshScanAndStartIfNeeded()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
        .onChange(of: currentFileURL) { _, _ in
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: refreshSignal) { _, _ in
            refreshScanAndReloadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.previewWindowDidBecomeActive()
        }
    }

    @EnvironmentObject private var themeVM: ThemeVM

    private func refreshScanAndStartIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.hostState == .connected || viewModel.hostState == .launching {
            viewModel.startHost()
        }
    }

    private func refreshScanAndReloadIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.hostState == .connected || viewModel.hostState == .rendering {
            viewModel.scheduleRenderFrame(reason: "editor refresh signal changed")
        }
    }
}
