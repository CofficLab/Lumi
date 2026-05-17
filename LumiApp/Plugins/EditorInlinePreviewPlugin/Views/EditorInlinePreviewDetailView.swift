import AppKit
import LumiInlinePreviewKit
import os
import SwiftUI

/// 内嵌预览插件的底部面板内容视图。
///
/// Phase 2 / 2.5 提供三条路径：
/// - **Render Demo Frame**：主进程内 `DemoSurfaceFactory`，验证显示链路。
/// - **Start / Stop Stream**：启动 `LumiInlinePreviewHostApp` 子进程，订阅
///   60fps `frameProduced` 事件，实时显示子进程跑的 SwiftUI demo。
/// - **Load Dylib…**：手动挑选一个用户编译产出的预览 dylib，让子进程 `dlopen`
///   并把其 `lumi_preview_make_nsview` 导出的 `NSView` 挂为 previewView。
///   后续阶段会把这一步自动化（扫描 → 编译 → 加载）。
struct EditorInlinePreviewDetailView: View {

    @EnvironmentObject private var editorVM: EditorVM
    @StateObject private var viewModel = EditorInlinePreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasArea
        }
        .onAppear {
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("📺 onAppear — currentFile=\(currentFileURL?.lastPathComponent ?? "nil")")
            }
            viewModel.setActiveFile(currentFileURL, sourceText: sourceText)
        }
        .onChange(of: currentFileURL) { _, newValue in
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("📄 currentFileURL changed → \(newValue?.lastPathComponent ?? "nil")")
            }
            viewModel.setActiveFile(newValue, sourceText: sourceText)
        }
        .onChange(of: editorVM.service.saveRevision) { _, _ in
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("💾 saveRevision changed")
            }
            // 仅在保存时触发重建，对齐 Xcode 的 #Preview 刷新策略。
            viewModel.applySaveRevision(sourceText: sourceText)
        }
        .onChange(of: editorVM.service.contentRevision) { _, _ in
            // 编辑过程中只 stash buffer，让下次保存能拿到最新内容；不重建。
            viewModel.updateBufferText(sourceText)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("🖱 clicked Demo Frame button")
                }
                viewModel.renderDemoFrame()
            } label: {
                Label("Demo Frame", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.status == .running || viewModel.status == .starting)
            .help("Generate a one-shot IOSurface in this process to verify the embedded display pipeline.")

            sessionToggleButton

            Divider().frame(height: 16)

            entryControls

            Spacer()

            entryStatusBadge

            statusBadge

            if let frame = viewModel.currentFrame {
                Text("seq \(frame.seq) · \(frame.width)×\(frame.height) @\(String(format: "%.0fx", frame.scale))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var entryControls: some View {
        Button {
            pickDylibAndLoad()
        } label: {
            Label("Load Dylib…", systemImage: "tray.and.arrow.down.fill")
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.status != .running)
        .help("Pick a .dylib that exports lumi_preview_make_nsview and let the subprocess render it.")

        if isEntryActive {
            Button {
                viewModel.unloadDylib()
            } label: {
                Label("Reset Demo", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.status != .running)
            .help("Unload the user dylib and restore the built-in demo view.")
        }
    }

    @ViewBuilder
    private var entryStatusBadge: some View {
        switch viewModel.entryStatus {
        case .demo:
            EmptyView()
        case .building(let file):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("building \(file)")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case .loading(let path):
            Text("loading \((path as NSString).lastPathComponent)")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .truncationMode(.middle)
        case .loaded(_, let title):
            Text("entry · \(title)")
                .font(.caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        case .failed(let message):
            Text("entry failed: \(message)")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var isEntryActive: Bool {
        switch viewModel.entryStatus {
        case .demo: return false
        case .building, .loading, .loaded, .failed: return true
        }
    }

    private func pickDylibAndLoad() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.message = "Select a preview .dylib that exports lumi_preview_make_nsview"
        panel.prompt = "Load"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadDylib(at: url)
        }
    }

    private var sessionToggleButton: some View {
        Group {
            switch viewModel.status {
            case .idle, .failed:
                Button {
                    viewModel.startSession()
                } label: {
                    Label("Start Stream", systemImage: "play.fill")
                }
                .buttonStyle(.borderless)
            case .starting:
                Button {} label: {
                    Label("Starting", systemImage: "hourglass")
                }
                .disabled(true)
                .buttonStyle(.borderless)
            case .running:
                Button {
                    viewModel.stopSession()
                } label: {
                    Label("Stop Stream", systemImage: "stop.fill")
                }
                .buttonStyle(.borderless)
            case .stopping:
                Button {} label: {
                    Label("Stopping", systemImage: "hourglass")
                }
                .disabled(true)
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .starting:
            Text("starting").font(.caption).foregroundStyle(.orange)
        case .running:
            Text("running · \(viewModel.policy.rawValue)").font(.caption).foregroundStyle(.green)
        case .stopping:
            Text("stopping").font(.caption).foregroundStyle(.orange)
        case .failed(let message):
            Text("failed: \(message)")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasArea: some View {
        let hasFrame = viewModel.currentFrame != nil
        ZStack {
            LumiInlinePreviewFacade.PreviewSurfaceCanvas(
                surfaceID: viewModel.currentFrame?.surfaceID,
                isInteractive: viewModel.isInteractive,
                onSizeChange: { size, scale in
                    viewModel.canvasDidResize(size, scale: scale)
                },
                onInputEvent: { event in
                    viewModel.forwardInputEvent(event)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !hasFrame {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Click \"Start Stream\" to launch the preview subprocess. Open a Swift file with a `#Preview` and press ⌘S to auto-build & render it.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
