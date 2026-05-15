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

    private var projectRootPath: String? {
        editorVM.service.projectRootPath
    }

    var body: some View {
        VStack(spacing: 0) {
            HotPreviewToolbar(viewModel: viewModel, currentFileURL: currentFileURL)
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
                onWindowMiniaturized: {
                    viewModel.previewWindowDidMiniaturize()
                },
                onWindowDeminiaturized: {
                    viewModel.previewWindowDidDeminiaturize()
                },
                onWindowFrameChanged: {
                    EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
                },
                onWindowVisibilityChanged: { isVisible in
                    if isVisible {
                        viewModel.previewWindowDidBecomeActive()
                    } else {
                        viewModel.previewWindowDidBecomeInactive()
                    }
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
        .onChange(of: editorVM.service.saveRevision) { _, _ in
            // Reload preview only when the user saves the file (Cmd+S),
            // matching the behavior of Xcode and other major editors.
            refreshScanAndReloadIfNeeded()
        }
        .onChange(of: editorVM.service.contentRevision) { _, _ in
            // Keep the in-memory source text and preview list in sync while editing,
            // but do NOT trigger a preview reload until save.
            viewModel.update(sourceText: sourceText, fileURL: currentFileURL, projectRootPath: projectRootPath, reloadPolicy: .scanOnly)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.previewAppDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            viewModel.previewAppDidResignActive()
            EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
        }
    }

    @EnvironmentObject private var themeVM: ThemeVM

    @ViewBuilder
    private var content: some View {
        if viewModel.isImageMode {
            if let fileURL = viewModel.imageFileURL {
                EditorPreviewImageView(fileURL: fileURL)
            } else {
                HotPreviewMessageView(
                    systemImage: "photo",
                    message: String(localized: "The current image could not be loaded.", table: "EditorPreviewRemoteHotPlugin"),
                    color: .orange
                )
            }
        } else if viewModel.isMarkdownMode {
            if let markdownSource = viewModel.markdownSource {
                EditorPreviewMarkdownView(markdown: markdownSource)
            } else {
                HotPreviewMessageView(
                    systemImage: "doc.richtext",
                    message: String(localized: "The current Markdown content is unavailable.", table: "EditorPreviewRemoteHotPlugin"),
                    color: .orange
                )
            }
        } else if viewModel.previews.count <= 1 {
            HotPreviewCanvas(viewModel: viewModel)
        } else {
            HStack(spacing: 0) {
                HotPreviewList(viewModel: viewModel)
                    .frame(width: 230)
                Divider()
                HotPreviewCanvas(viewModel: viewModel)
            }
        }
    }

    private func refreshScanAndStartIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL, projectRootPath: projectRootPath)
        guard !viewModel.isImageMode, !viewModel.isMarkdownMode else { return }
        if viewModel.hostState == .idle || viewModel.hostState == .failed {
            viewModel.startHost()
        }
    }

    private func refreshScanAndReloadIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL, projectRootPath: projectRootPath)
        guard !viewModel.isImageMode, !viewModel.isMarkdownMode else { return }
        if viewModel.hostState == .connected || viewModel.hostState == .rendering {
            viewModel.scheduleRenderFrame(reason: "editor refresh signal changed")
        }
    }
}
